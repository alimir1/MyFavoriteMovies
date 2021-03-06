//
//  GCDBlackBox.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Edited and modified by Ali Mir on 10/19/2016
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation

func performUIUpdatesOnMain(updates: () -> Void) {
    dispatch_async(dispatch_get_main_queue()) {
        updates()
    }
}
