//
//  PostViewController.swift
//  lab-insta-parse
//
//  Created by Charlie Hieger on 11/1/22.
//

import UIKit
import CoreLocation
import PhotosUI
import ParseSwift

class PostViewController: UIViewController {

    // MARK: Outlets
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var captionTextField: UITextField!
    @IBOutlet weak var previewImageView: UIImageView!

    private var pickedImage: UIImage?
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    @IBAction func onPickedImageTapped(_ sender: UIBarButtonItem) {
        // TODO: Pt 1 - Present Image picker
        // Create and configure PHPickerViewController

        // Create a configuration object
        var config = PHPickerConfiguration()

        // Set the filter to only show images as options (i.e. no videos, etc.).
        config.filter = .images

        // Request the original file format. Fastest method as it avoids transcoding.
        config.preferredAssetRepresentationMode = .current

        // Only allow 1 image to be selected at a time.
        config.selectionLimit = 1

        // Instantiate a picker, passing in the configuration.
        let picker = PHPickerViewController(configuration: config)

        // Set the picker delegate so we can receive whatever image the user picks.
        picker.delegate = self

        // Present the picker
        present(picker, animated: true)
    }

    @IBAction func onShareTapped(_ sender: Any) {
        // Dismiss Keyboard
        view.endEditing(true)

        // TODO: Pt 1 - Create and save Post

        // Unwrap optional pickedImage
        guard let image = pickedImage,
              let imageData = image.jpegData(compressionQuality: 0.1) else {
            return
        }

        do {
            // Create a Parse File by providing a name and passing in the image data
            let imageFile = try ParseFile(name: "image.jpg", data: imageData)

            var post = Post()
            post.imageFile = imageFile
            post.caption = captionTextField.text
            post.user = User.current

            // Reverse geocode to get place name (e.g. "Washington, DC"), then save
            if let location = currentLocation {
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
                    let lat = location.coordinate.latitude
                    let lng = location.coordinate.longitude
                    let coords = "\(lat),\(lng)"
                    if let place = placemarks?.first {
                        let name = self?.placeName(from: place) ?? coords
                        post.location = "\(name)|\(coords)"
                    } else {
                        post.location = coords
                    }
                    self?.savePostAndUpdateUser(post)
                }
            } else {
                savePostAndUpdateUser(post)
            }
        } catch {
            showAlert(description: error.localizedDescription)
        }
    }

    private func placeName(from placemark: CLPlacemark) -> String {
        var parts: [String] = []
        if let locality = placemark.locality { parts.append(locality) }
        if let state = placemark.administrativeArea, state != parts.first { parts.append(state) }
        if let country = placemark.country, !parts.contains(country) { parts.append(country) }
        return parts.isEmpty ? (placemark.name ?? "Unknown") : parts.joined(separator: ", ")
    }

    private func savePostAndUpdateUser(_ post: Post) {
        post.save { [weak self] result in
            switch result {
            case .success:
                print("✅ Post Saved!")

                // Update user's lastPostedDate so feed visibility rules apply
                if var currentUser = User.current {
                    currentUser.lastPostedDate = Date()
                    currentUser.save { [weak self] saveResult in
                        switch saveResult {
                        case .success:
                            print("✅ User lastPostedDate updated")
                            DispatchQueue.main.async {
                                self?.navigationController?.popViewController(animated: true)
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                self?.showAlert(description: error.localizedDescription)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showAlert(description: error.localizedDescription)
                }
            }
        }
    }

    @IBAction func onTakePhotoTapped(_ sender: Any) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("❌📷 Camera not available")
            showAlert(description: "Camera is not available on this device.")
            return
        }
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
        present(imagePicker, animated: true)
    }

    @IBAction func onViewTapped(_ sender: Any) {
        // Dismiss keyboard
        view.endEditing(true)
    }
}

// TODO: Pt 1 - Add PHPickerViewController delegate and handle picked image.
extension PostViewController: PHPickerViewControllerDelegate {

    // PHPickerViewController required delegate method.
    // Returns PHPicker result containing picked image data.
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {

        // Dismiss the picker
        picker.dismiss(animated: true)

        // Make sure we have a non-nil item provider
        guard let provider = results.first?.itemProvider,
              // Make sure the provider can load a UIImage
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        // Load a UIImage from the provider
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in

            // Make sure we can cast the returned object to a UIImage
            guard let image = object as? UIImage else {
                self?.showAlert()
                return
            }

            // Check for and handle any errors
            if let error = error {
                self?.showAlert(description: error.localizedDescription)
                return
            } else {

                // UI updates (like setting image on image view) should be done on main thread
                DispatchQueue.main.async {

                    // Set image on preview image view
                    self?.previewImageView.image = image

                    // Set image to use when saving post
                    self?.pickedImage = image
                }
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension PostViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else {
            print("❌📷 Unable to get image")
            return
        }
        previewImageView.image = image
        pickedImage = image
    }
}

// MARK: - CLLocationManagerDelegate
extension PostViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
}
