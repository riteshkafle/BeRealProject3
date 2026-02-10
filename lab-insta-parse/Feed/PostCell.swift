//
//  PostCell.swift
//  lab-insta-parse
//
//  Created by Charlie Hieger on 11/3/22.
//

import UIKit
import Alamofire
import AlamofireImage
import ParseSwift

class PostCell: UITableViewCell {

    @IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var postImageView: UIImageView!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var locationLabel: UILabel!
    @IBOutlet private weak var commentsLabel: UILabel!

    // Blur view to blur out "hidden" posts (UIVisualEffectView)
    @IBOutlet private weak var blurView: UIVisualEffectView!

    private var imageDataRequest: DataRequest?

    func configure(with post: Post, comments: [Comment] = []) {
        // Username
        if let user = post.user {
            usernameLabel.text = user.username
        }

        // Image
        if let imageFile = post.imageFile,
           let imageUrl = imageFile.url {
            imageDataRequest = AF.request(imageUrl).responseImage { [weak self] response in
                switch response.result {
                case .success(let image):
                    self?.postImageView.image = image
                case .failure(let error):
                    print("❌ Error fetching image: \(error.localizedDescription)")
                }
            }
        }

        captionLabel.text = post.caption

        // Time — relative (e.g. "1 min ago", "2 hours ago")
        if let date = post.createdAt {
            dateLabel.text = date.relativeString
        }

        // Location — show place name (e.g. "Washington, DC") when stored as "PlaceName|lat,lng"
        if let locationString = post.location, !locationString.isEmpty {
            if locationString.contains("|") {
                let placeName = locationString.split(separator: "|").first.map(String.init) ?? locationString
                locationLabel.text = "📍 \(placeName)"
            } else {
                let parts = locationString.split(separator: ",")
                if parts.count == 2, let _ = Double(parts[0]), let _ = Double(parts[1]) {
                    locationLabel.text = "📍 \(locationString)"
                } else {
                    locationLabel.text = "📍 \(locationString)"
                }
            }
        } else {
            locationLabel.text = "Location: Not set"
        }
        locationLabel.isHidden = false

        // Comment section: commentor's username and comment content
        if comments.isEmpty {
            commentsLabel.text = nil
            commentsLabel.isHidden = true
        } else {
            commentsLabel.isHidden = false
            commentsLabel.text = comments.prefix(5).compactMap { c -> String? in
                let name = c.user?.username ?? "Someone"
                guard let text = c.text, !text.isEmpty else { return nil }
                return "\(name): \(text)"
            }.joined(separator: "\n")
        }

        // Show blur unless: user has posted at least once AND this post's createdAt is within 24h of user's last post
        if let currentUser = User.current,
           let lastPostedDate = currentUser.lastPostedDate,
           let postCreatedDate = post.createdAt,
           let diffHours = Calendar.current.dateComponents([.hour], from: postCreatedDate, to: lastPostedDate).hour {
            blurView.isHidden = abs(diffHours) < 24
        } else {
            // User hasn't posted yet, or missing dates: blur so they can't see others' photos
            blurView.isHidden = false
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        postImageView.image = nil
        locationLabel.text = nil
        commentsLabel.text = nil
        commentsLabel.isHidden = true
        blurView.isHidden = true
        imageDataRequest?.cancel()
    }
}
