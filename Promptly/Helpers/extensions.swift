//
//  extensions.swift
//  Talker2
//
//  Created by Cole Hershkowitz on 5/15/23.
//

import Foundation

extension Optional {
    var NAIfNil: String {
        switch self {
        case .some(let value):
            return String(describing: value)
        case .none:
            return "NA"
        }
    }
}
