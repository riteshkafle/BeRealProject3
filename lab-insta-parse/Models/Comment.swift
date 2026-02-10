//
//  Comment.swift
//  lab-insta-parse
//

import Foundation
import ParseSwift

/// Parse object for comments on posts. Displays commentor's username and comment content.
struct Comment: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    var post: Post?
    var user: User?
    var text: String?
}
