//
//  LoginViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Edited and modified by Ali Mir on 10/19/2016
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - LoginViewController: UIViewController

class LoginViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: BorderedButton!
    @IBOutlet weak var debugTextLabel: UILabel!
    @IBOutlet weak var movieImageView: UIImageView!
        
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate                        
        
        configureUI()
        
        subscribeToNotification(UIKeyboardWillShowNotification, selector: #selector(keyboardWillShow))
        subscribeToNotification(UIKeyboardWillHideNotification, selector: #selector(keyboardWillHide))
        subscribeToNotification(UIKeyboardDidShowNotification, selector: #selector(keyboardDidShow))
        subscribeToNotification(UIKeyboardDidHideNotification, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Login
    
    @IBAction func loginPressed(sender: AnyObject) {
        
        userDidTapView(self)
        
        if usernameTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            debugTextLabel.text = "Username or Password Empty."
        } else {
            setUIEnabled(false)
            
            /*
                Steps for Authentication...
                https://www.themoviedb.org/documentation/api/sessions
                
                Step 1: Create a request token
                Step 2: Ask the user for permission via the API ("login")
                Step 3: Create a session ID
                
                Extra Steps...
                Step 4: Get the user id ;)
                Step 5: Go to the next view!            
            */
            getRequestToken()
        }
    }
    
    private func completeLogin() {
        performUIUpdatesOnMain {
            self.debugTextLabel.text = ""
            self.setUIEnabled(true)
            let controller = self.storyboard!.instantiateViewControllerWithIdentifier("MoviesTabBarController") as! UITabBarController
            self.presentViewController(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: TheMovieDB
    
    private func getRequestToken() {
        
        /* TASK: Get a request token, then store it (appDelegate.requestToken) and login with the token */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = NSURLRequest(URL: appDelegate.tmdbURLFromParameters(methodParameters, withPathExtension: "/authentication/token/new"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTaskWithRequest(request) { (data, response, error) in
            
            /* 5. Parse the data */
            // If error occurs, print it and re-enable the UI
            func displayError(error: String) {
                performUIUpdatesOnMain {
                    print(error)
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login Failed (Request Token)"
                }
            }
            
            guard (error == nil) else {
                displayError("There was an error with requesting.")
                return
            }
            
            guard let data = data else {
                displayError("Data was not returned.")
                return
            }
            
            guard let response = response as? NSHTTPURLResponse where 200...299 ~= response.statusCode else {
                displayError("Not a successful response code 2xx.")
                return
            }
            
            let parsedData: AnyObject!
            do {
                parsedData = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayError("Could not parse data into JSON: \(data). Error: \(error)")
                return
            }

            guard (parsedData[Constants.TMDBResponseKeys.Success] as? Bool) == true else {
                displayError("Response not successful \(parsedData)")
                return
            }
            
            guard let requestToken = parsedData[Constants.TMDBResponseKeys.RequestToken] as? String else {
                displayError("Request token not found. \(parsedData)")
                return
            }
            
            print("Wohoo!!! Request token found!!! \(requestToken)")
            
            /* 6. Use the data! */
            self.appDelegate.requestToken = requestToken
            self.loginWithToken(requestToken)
            
        }

        /* 7. Start the request */
        task.resume()
    }
    
    private func loginWithToken(requestToken: String) {
        
        /* TASK: Login, then get a session id */
        /* 1. Set the parameters */
        let methodParameters = [Constants.TMDBParameterKeys.ApiKey : Constants.TMDBParameterValues.ApiKey,
                                Constants.TMDBParameterKeys.Username : usernameTextField.text!,
                                Constants.TMDBParameterKeys.Password : passwordTextField.text!,
                                Constants.TMDBParameterKeys.RequestToken : appDelegate.requestToken!]

        /* 2/3. Build the URL, Configure the request */
        let request = NSURLRequest(URL: appDelegate.tmdbURLFromParameters(methodParameters, withPathExtension: "/authentication/token/validate_with_login"))
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTaskWithRequest(request) { (data, response, error) in
            
            func displayErrorSetup(error: String) {
                performUIUpdatesOnMain {
                    self.debugTextLabel.text = "Login failed with requested token"
                    self.setUIEnabled(true)
                    print(error)
                }
            }
            
            guard (error == nil) else {
                displayErrorSetup("There was an error.")
                return
            }
            
            guard let response = response as? NSHTTPURLResponse where 200...299 ~= response.statusCode else {
                displayErrorSetup("Response not successful (not in 2xx range).")
                return
            }
            
            guard let data = data else {
                displayErrorSetup("Could not get the data successfully")
                return
            }
            
            /* 5. Parse the data */
            let parsedData: AnyObject!
            do {
                parsedData = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayErrorSetup("Could not parse the data. Error: \(error), Data: \(data)")
                return
            }
            
            guard (parsedData[Constants.TMDBResponseKeys.Success] as? Bool == true) else {
                displayErrorSetup("Request token not valid. \(parsedData)")
                return
            }
            
            /* 6. Use the data! */
            self.getSessionID(self.appDelegate.requestToken!)
        }
        
        /* 7. Start the request */
        task.resume()
    }
    
    private func getSessionID(requestToken: String) {
        
        /* TASK: Get a session ID, then store it (appDelegate.sessionID) and get the user's id */
        
        /* 1. Set the parameters */
        let methodParameters = [Constants.TMDBParameterKeys.ApiKey : Constants.TMDBParameterValues.ApiKey,
                                Constants.TMDBParameterKeys.RequestToken : appDelegate.requestToken!]
        /* 2/3. Build the URL, Configure the request */
        let request = NSURLRequest(URL: appDelegate.tmdbURLFromParameters(methodParameters, withPathExtension: "/authentication/session/new"))
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTaskWithRequest(request) {
            (data, response, error) in
            /* 5. Parse the data */
            func displayErrorSetup(error: String) {
                performUIUpdatesOnMain {
                    print(error)
                    self.debugTextLabel.text = "Session ID error"
                    self.setUIEnabled(true)
                }
            }
            
            guard (error == nil) else {
                displayErrorSetup("Error in requesting.")
                return
            }
            
            guard let response = response as? NSHTTPURLResponse where 200...299 ~= response.statusCode else {
                displayErrorSetup("Not a successful response")
                return
            }
            
            guard let data = data  else {
                displayErrorSetup("Could not get data")
                return
            }
            
            let parsedData: AnyObject!
            do {
                parsedData = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayErrorSetup("Error in converting data into JSON. Error: \(error), Data: \(data)")
                return
            }
            
            guard let sessionID = parsedData[Constants.TMDBParameterKeys.SessionID] as? String else {
                displayErrorSetup("Could not get the session ID. \(parsedData)")
                return
            }
            /* 6. Use the data! */
            print("Session ID: \(sessionID)")
            self.appDelegate.sessionID = sessionID
        }
        
        
        /* 7. Start the request */
        task.resume()
    }
    
    private func getUserID(sessionID: String) {
        
        /* TASK: Get the user's ID, then store it (appDelegate.userID) for future use and go to next view! */
        
        /* 1. Set the parameters */
        /* 2/3. Build the URL, Configure the request */
        /* 4. Make the request */
        /* 5. Parse the data */
        /* 6. Use the data! */
        /* 7. Start the request */
    }
}

// MARK: - LoginViewController: UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
            movieImageView.hidden = true
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
            movieImageView.hidden = false
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(usernameTextField)
        resignIfFirstResponder(passwordTextField)
    }
}

// MARK: - LoginViewController (Configure UI)

extension LoginViewController {
    
    private func setUIEnabled(enabled: Bool) {
        usernameTextField.enabled = enabled
        passwordTextField.enabled = enabled
        loginButton.enabled = enabled
        debugTextLabel.text = ""
        debugTextLabel.enabled = enabled
        
        // adjust login button alpha
        if enabled {
            loginButton.alpha = 1.0
        } else {
            loginButton.alpha = 0.5
        }
    }
    
    private func configureUI() {
        
        // configure background gradient
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [Constants.UI.LoginColorTop, Constants.UI.LoginColorBottom]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.frame
        view.layer.insertSublayer(backgroundGradient, atIndex: 0)
        
        configureTextField(usernameTextField)
        configureTextField(passwordTextField)
    }
    
    private func configureTextField(textField: UITextField) {
        let textFieldPaddingViewFrame = CGRectMake(0.0, 0.0, 13.0, 0.0)
        let textFieldPaddingView = UIView(frame: textFieldPaddingViewFrame)
        textField.leftView = textFieldPaddingView
        textField.leftViewMode = .Always
        textField.backgroundColor = Constants.UI.GreyColor
        textField.textColor = Constants.UI.BlueColor
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder!, attributes: [NSForegroundColorAttributeName: UIColor.whiteColor()])
        textField.tintColor = Constants.UI.BlueColor
        textField.delegate = self
    }
}

// MARK: - LoginViewController (Notifications)

extension LoginViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
