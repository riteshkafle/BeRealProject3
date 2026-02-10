//
//  LoginViewController.swift
//  lab-insta-parse
//
//  Created by Charlie Hieger on 10/29/22.
//

import UIKit
import UserNotifications
import ParseSwift

class LoginViewController: UIViewController {

    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func onLoginTapped(_ sender: Any) {

        // Make sure all fields are non-nil and non-empty.
        guard let username = usernameField.text,
              let password = passwordField.text,
              !username.isEmpty,
              !password.isEmpty else {

            showMissingFieldsAlert()
            return
        }

        // TODO: Pt 1 - Log in the parse user
        User.login(username: username, password: password) { [weak self] result in

            switch result {
            case .success(let user):
                print("✅ Successfully logged in as user: \(user)")
                self?.requestNotificationPermissionAndScheduleReminder()
                NotificationCenter.default.post(name: Notification.Name("login"), object: nil)
            case .failure(let error):
                // Show an alert for any errors
                self?.showAlert(description: error.localizedDescription)
            }
        }
    }

    private func showMissingFieldsAlert() {
        let alertController = UIAlertController(title: "Opps...", message: "We need all fields filled out in order to log you in.", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        present(alertController, animated: true)
    }

    /// Request notification permission and schedule a local reminder to post (stretch feature).
    private func requestNotificationPermissionAndScheduleReminder() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard granted else { return }
            self?.schedulePostReminderNotification()
        }
    }

    private func schedulePostReminderNotification() {
        let center = UNUserNotificationCenter.current()

        // 1) Quick reminder so user sees a notification almost right away (3 seconds after login)
        let quickContent = UNMutableNotificationContent()
        quickContent.title = "BeReal"
        quickContent.body = "Time to post your BeReal!"
        quickContent.sound = .default
        let quickTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let quickRequest = UNNotificationRequest(identifier: "com.bereal.postReminderQuick", content: quickContent, trigger: quickTrigger)
        center.add(quickRequest)

        // 2) Daily repeating reminder (every 24 hours)
        let dailyContent = UNMutableNotificationContent()
        dailyContent.title = "BeReal"
        dailyContent.body = "Time to post your BeReal!"
        dailyContent.sound = .default
        let dailyTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 24, repeats: true)
        let dailyRequest = UNNotificationRequest(identifier: "com.bereal.postReminderDaily", content: dailyContent, trigger: dailyTrigger)
        center.add(dailyRequest)
    }
}

