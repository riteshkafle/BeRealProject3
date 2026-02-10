//
//  FeedViewController.swift
//  lab-insta-parse
//
//  Created by Charlie Hieger on 11/1/22.
//

import UIKit

// TODO: P1 1 - Import Parse Swift
import ParseSwift

class FeedViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    private let refreshControl = UIRefreshControl()

    private var posts = [Post]() {
        didSet { tableView.reloadData() }
    }
    /// Comments for each post, keyed by post objectId.
    private var commentsByPostId: [String: [Comment]] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = true
        tableView.estimatedRowHeight = 400
        tableView.rowHeight = UITableView.automaticDimension

        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(onPullToRefresh), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        queryPosts()
    }

    private func queryPosts(completion: (() -> Void)? = nil) {
        let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        do {
            let query = try Post.query()
                .include("user")
                .order([.descending("createdAt")])
                .where("createdAt" >= yesterdayDate)
                .limit(10)

            query.find { [weak self] result in
            switch result {
            case .success(let posts):
                self?.posts = posts
                self?.fetchCommentsForPosts(posts, completion: completion)
            case .failure(let error):
                self?.showAlert(description: error.localizedDescription)
                completion?()
            }
        }
        } catch {
            showAlert(description: error.localizedDescription)
            completion?()
        }
    }

    private func fetchCommentsForPosts(_ posts: [Post], completion: (() -> Void)? = nil) {
        guard !posts.isEmpty else {
            completion?()
            return
        }
        let group = DispatchGroup()
        var map: [String: [Comment]] = [:]
        let queue = DispatchQueue(label: "commentsFetch", attributes: .concurrent)
        for post in posts {
            guard let postId = post.objectId else { continue }
            group.enter()
            do {
                let query = try Comment.query()
                    .include("user")
                    .where("post" == post)
                query.find { result in
                switch result {
                case .success(let comments):
                    queue.async(flags: .barrier) { map[postId] = comments }
                case .failure:
                    break
                }
                group.leave()
                }
            } catch {
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.commentsByPostId = map
            self?.tableView.reloadData()
            completion?()
        }
    }

    @IBAction func onLogOutTapped(_ sender: Any) {
        showConfirmLogoutAlert()
    }

    @objc private func onPullToRefresh() {
        refreshControl.beginRefreshing()
        queryPosts { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    private func showConfirmLogoutAlert() {
        let alertController = UIAlertController(title: "Log out of \(User.current?.username ?? "current account")?", message: nil, preferredStyle: .alert)
        let logOutAction = UIAlertAction(title: "Log out", style: .destructive) { _ in
            NotificationCenter.default.post(name: Notification.Name("logout"), object: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(logOutAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }
}

extension FeedViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as? PostCell else {
            return UITableViewCell()
        }
        let post = posts[indexPath.row]
        let comments = post.objectId.flatMap { commentsByPostId[$0] } ?? []
        cell.configure(with: post, comments: comments)
        return cell
    }
}

extension FeedViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let post = posts[indexPath.row]
        showAddCommentAlert(for: post)
    }

    private func showAddCommentAlert(for post: Post) {
        let alert = UIAlertController(title: "Add Comment", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Your comment..." }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Post", style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self?.saveComment(text: text.trimmingCharacters(in: .whitespacesAndNewlines), for: post)
        })
        present(alert, animated: true)
    }

    private func saveComment(text: String, for post: Post) {
        var comment = Comment()
        comment.post = post
        comment.user = User.current
        comment.text = text
        comment.save { [weak self] result in
            switch result {
            case .success:
                self?.queryPosts()
            case .failure(let error):
                self?.showAlert(description: error.localizedDescription)
            }
        }
    }
}
