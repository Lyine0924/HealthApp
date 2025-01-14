//
//  ProfileViewController.swift
//  HealthApp
//
//  Created by Moisés Córdova on 7/5/19.
//  Copyright © 2019 Moisés Córdova. All rights reserved.
//

import UIKit
import FirebaseStorage
import RealmSwift
import FloatingPanel

class ProfileViewController: UIViewController {
    private let refreshControl = UIRefreshControl()
    let realm = try? Realm()
    var patient: Patient?
    var collectionView: UICollectionView!
    var backgroundImages: [UIImage] = [#imageLiteral(resourceName: "hardBlueGradient"), #imageLiteral(resourceName: "blueGradient"), #imageLiteral(resourceName: "purpleGradient"), #imageLiteral(resourceName: "pinkGradient")]
    var optionPressed = -1
    var todaySteps = 0
    var fpc: FloatingPanelController!
    var QRVC: QRViewController!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        HealthKitService.shared.authorizeHealthKit()
        setRefreshControl()
        
        //NotificationCenter.default.addObserver(self, selector: #selector(initMethods), name: Notification.Name("healthKitAuth"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setInformation), name: Notification.Name("UpdateTableInfo"), object: nil)
        
        initMethods()
        createPanel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadTables()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func setRefreshControl() {
        tableView.refreshControl = refreshControl
        refreshControl.tintColor = UIColor.darkGray
        refreshControl.attributedTitle = NSAttributedString(string: "Fetching User Data ...", attributes: nil)
        refreshControl.addTarget(self, action: #selector(initMethods), for: .valueChanged)
    }
    
    func createPanel() {
        guard self.patient != nil else { return }
        // Initialize FloatingPanelController
        fpc = FloatingPanelController()
        fpc.delegate = self
        fpc.show()
        
        // Initialize FloatingPanelController and add the view
        fpc.surfaceView.cornerRadius = 30.0
        fpc.surfaceView.shadowHidden = true
        fpc.surfaceView.borderWidth = 1.0 / traitCollection.displayScale
        fpc.surfaceView.borderColor = UIColor.black.withAlphaComponent(0.2)
        
        QRVC = storyboard?.instantiateViewController(withIdentifier: "QRViewController") as? QRViewController
        QRVC.fpc = self.fpc
        QRVC.patientUID = self.patient?.uid
        
        fpc.set(contentViewController: QRVC)
        fpc.addPanel(toParent: self, belowView: nil, animated: false)
        fpc.hide()
    }
    
    @objc func initMethods() {
        setPatient()
        setPatientBasicData()
        setAllDetails()
        checkCloudInformation()
    }
    
    @objc func setInformation() {
        setPatientBasicData()
        setAllDetails()
        checkCloudInformation()
    }
    
    @objc func reloadTables() {
        if let tableView = self.tableView, let collectionView = self.collectionView {
            tableView.reloadData()
            collectionView.reloadData()
        }
    }
    
    @IBAction func scanQRButtonPressed(_ sender: UIButton) {
        let alert = UIAlertController(title: "Add a Doctor", message: "How do you want to add a new doctor?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Show my PatientID", style: .default, handler: { (action) in
            self.fpc.show(animated: true, completion: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "Scan DoctorID", style: .default, handler: { (action) in
            if let viewController = self.storyboard?.instantiateViewController(withIdentifier: "QRAnalyzerVC") as? QRAnalyzerViewController {
                viewController.patient = self.patient
                self.present(viewController, animated: true)
                return
            }
        }))
    
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    @IBAction func settingsButtonPressed(_ sender: UIButton) {
        let alert = UIAlertController(title: "Settings", message: "Settings", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    @objc func setPatientBasicData() {
        let (age, bloodType, biologicalSex) = HealthKitService.shared.getPacientBasicData()
        let readableBloodType = HealthKitService.shared.getReadable(bloodType: bloodType?.bloodType)
        let readableBiologicalSex = HealthKitService.shared.getReadable(biologicalSex: biologicalSex)
        let finalAge = age ?? 0
        
        DispatchQueue.main.async {
            do {
                try self.realm?.write {
                    
                    if self.patient?.age != finalAge {
                        self.patient?.age = finalAge
                    }
                    
                    if self.patient?.biologicalSex != readableBiologicalSex {
                        self.patient?.biologicalSex = readableBiologicalSex
                    }
                    
                    if self.patient?.bloodType != readableBloodType {
                        self.patient?.bloodType = readableBloodType
                    }
                    
                    self.realm?.add(self.patient!)
                }
            } catch {
                print("Error Saving: \(error.localizedDescription)")
            }
        }
    }
    
    func setPatient() {
        if let myPatient = realm?.objects(Patient.self).first {
            self.patient = myPatient
        } else {
            if let uid = AuthService.shared.fireabseAuth.currentUser?.uid {
                self.patient = Patient(uid: uid)
                do {
                    try realm?.write {
                        realm?.add(patient!)
                    }
                } catch {
                    print("Error Saving user: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    func checkCloudInformation() {
        if let patientUID = AuthService.shared.fireabseAuth.currentUser?.uid {
            DatabaseService.shared.patientsRef.child(patientUID).observeSingleEvent(of: .value) { (snapshot) in
                if let patient = snapshot.value as? Dictionary<String, AnyObject> {
                    if let profile = patient["profile"] as? Dictionary<String, AnyObject> {
                        DispatchQueue.main.async {
                            self.checkChanges(userDict: profile)
                            self.downloadProfileImage(userDict: profile)
                        }
                    }
                }
            }
        }
    }
    
    func downloadProfileImage(userDict: Dictionary<String, AnyObject>) {
        if let profilePictureURL = userDict["profilePicture"] as? Dictionary<String, AnyObject> {
            if let imageURL = profilePictureURL["profilePictureURL"] as? String {
                let httpRef = Storage.storage().reference(forURL: imageURL)
                httpRef.getData(maxSize: 15*1024*1024, completion: { (data, error) in
                    if error != nil {
                        print("Error al descargar la imagen: \(String(describing: error?.localizedDescription))")
                    } else {
                        do {
                            try self.realm?.write {
                                self.patient?.dataProfilePicture = data
                            }
                        } catch {
                            print("No se pudo poner la imagen")
                        }
                    }
                    self.refreshControl.endRefreshing()
                    self.tableView.reloadData()
                })
            }
        }
    }
    
    func checkChanges(userDict: Dictionary<String, AnyObject>) {
        var hasUser = true
        guard let uid = AuthService.shared.fireabseAuth.currentUser?.uid else { return }
        if patient == nil {
            patient = Patient(uid: uid)
            hasUser = false
        }
        
        guard let myDict = userDict["basicData"] else { return }
        
        if let firstName = myDict["firstName"] as? String,
        let lastName = myDict["lastName"] as? String,
        let email = myDict["email"] as? String
        {
            do {
                try realm?.write {
                    if patient?.firstName != firstName { patient?.firstName = firstName }
                    if patient?.lastName  != lastName  { patient?.lastName = lastName   }
                    if patient?.email     != email     { patient?.email = email         }
                }
            } catch {
                print("Error writting: \(error.localizedDescription)")
            }
        }
        
        if !hasUser {
            do {
                try realm?.write {
                    realm?.add(patient!.self)
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        reloadTables()
    }
    
    // 이부분도 참고 필요
    func setAllDetails() {
        let initialDate = Date(timeIntervalSince1970: TimeInterval())
        let today = Date()
        HealthKitService.shared.getStepsCount(forSpecificDate: today) { (steps) in
            self.todaySteps = Int(steps)
        }
        HealthKitService.shared.weightRecords(from: initialDate, to: today, patient: patient!)
        HealthKitService.shared.heightRecords(from: initialDate, to: today, patient: patient!)
        HealthKitService.shared.getSleepAnalysis(from: initialDate, to: today, patient: patient!)
        HealthKitService.shared.getHearthRate(from: initialDate, to: today, patient: patient!)
        HealthKitService.shared.getActiveEnergy(patient: patient!)
        HealthKitService.shared.dietaryInformation(from: initialDate, to: today, patient: patient!)
        
        self.patient?.saveHealthInfoInFirebase()
    }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource, UICollectionViewDataSource, UICollectionViewDelegate, FloatingPanelControllerDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 8
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath) as! ProfileTableViewCell
            cell.nameLabel.text = patient?.firstName
            cell.genderLabel.text = patient?.biologicalSex
            cell.profileImageView.setRounded()
            cell.profileImageView.image = patient?.profilePicture ?? UIImage(named: "profile-placeholder")
            cell.selectionStyle = .none
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionCell", for: indexPath) as! CollectionViewTableViewCell
            self.collectionView = cell.collectionView
            cell.selectionStyle = .none
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cardCell", for: indexPath) as! CardTableViewCell
            cell.selectionStyle = .none
            if indexPath.row == 2 {
                cell.cardView.backgroundColor = #colorLiteral(red: 0.9553055167, green: 0.5355370045, blue: 0.399112761, alpha: 1)
                cell.titleLabel.text = "Calories Burned"
                cell.topicIcon.image = UIImage(named: "burn-icon")!
                cell.descriptionLabel.text = "This is the count of calories burned with your activity throughout the day"
                cell.quantityLabel.text = String(format: "%.0f", patient!.workoutRecords.last?.calories ?? 0.0)
            } else if indexPath.row == 3 {
                cell.cardView.backgroundColor = #colorLiteral(red: 0.2653386891, green: 0.2729498446, blue: 0.6093763709, alpha: 1)
                cell.titleLabel.text = "Hours sleeping"
                cell.topicIcon.image = UIImage(named: "moon-icon")!
                cell.descriptionLabel.text = "It takes the count of the hours in bed of the last night"
                cell.quantityLabel.text = "\(patient!.sleepRecords.last?.hoursSleeping ?? "0 h")"
            } else if indexPath.row == 4 {
                cell.cardView.backgroundColor = #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1)
                cell.titleLabel.text = "Weight Records"
                cell.topicIcon.image = UIImage(named: "weight-icon")!
                cell.descriptionLabel.text = "My Last weight measurament on kilograms"
                cell.quantityLabel.text = HealthKitService.shared.getFormated(measure: patient?.weightRecords.last?.weight ?? 0.0, on: .kilogram)
                
            } else if indexPath.row == 5 {
                cell.cardView.backgroundColor = #colorLiteral(red: 0.9411764741, green: 0.4980392158, blue: 0.3529411852, alpha: 1)
                cell.titleLabel.text = "Hearth BPM"
                cell.topicIcon.image = UIImage(named: "hearth-icon")!
                cell.descriptionLabel.text = "A record of beats per minute is recorded in different activities"
                cell.quantityLabel.text = "\(patient!.hearthRecords.last?.bpm ?? 0)"
            } else if indexPath.row == 6 {
                cell.cardView.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
                cell.titleLabel.text = "Food calories"
                cell.topicIcon.image = UIImage(named: "food-icon")!
                cell.descriptionLabel.text = "My last food ingested - \(patient?.ingestedFoods.last?.name ?? "")"
                cell.quantityLabel.text = String(format: "%.0f", patient!.ingestedFoods.last?.kilocalories ?? 0.0)
            } else if indexPath.row == 7 {
                cell.cardView.backgroundColor = #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1)
                cell.titleLabel.text = "Nevus Analyzer"
                cell.topicIcon.image = UIImage(named: "bodyScan-icon")!
                cell.descriptionLabel.text = "Detection by artificial intelligence of a nevus' pathology"
                cell.quantityLabel.text = "GO!"
            }
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 70.0
        switch indexPath.row {
        case 1:
            height = 100.0
        default:
            height = 210.0
        }
        
        return height
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 7 {
            if let viewController = storyboard?.instantiateViewController(withIdentifier: "VisualRecognizerVC") {
                present(viewController, animated: true)
                return
            }
        } else if indexPath.row > 1 {
            optionPressed = indexPath.row
            performSegue(withIdentifier: "tableSegue", sender: nil)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DataCollectionCell", for: indexPath) as! DataCollectionViewCell
        cell.bacgroundImage.image = self.backgroundImages[indexPath.row]
        switch indexPath.row {
        case 0:
            cell.dataLabel.text = "\(todaySteps)"
            cell.descriptionLabel.text = "Steps"
        case 1:
            cell.dataLabel.text = patient?.workoutRecords.last?.calories.withoutDecimals ?? "0"
            cell.descriptionLabel.text = "Calories"
        case 2:
            cell.dataLabel.text = "Height"
            cell.descriptionLabel.text = String(format: "%.1f", patient?.heightRecords.last?.height ?? 0.0) + " mt"
        default:
            cell.dataLabel.text = "Weight"
            cell.descriptionLabel.text = HealthKitService.shared.getFormated(measure: patient?.weightRecords.last?.weight ?? 0.0, on: .kilogram)
        }
        
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "tableSegue" {
            if let navigationController = segue.destination as? UINavigationController {
                if let viewController = navigationController.topViewController as? RecordViewController {
                    var title = ""
                    var color = UIColor()
                    var icon = UIImage()
                    switch optionPressed {
                    case 2:
                        let records = Array(patient!.workoutRecords)
                        viewController.myRecords = records as [AnyObject]
                        title = "Calories Burned"
                        color = #colorLiteral(red: 0.9723386168, green: 0.5278795958, blue: 0.4031898975, alpha: 1)
                        icon = UIImage(named: "burn-icon")!
                    case 3:
                        let records = Array(patient!.sleepRecords)
                        viewController.myRecords = records as [AnyObject]
                        title = "Sleeping Hours"
                        color = #colorLiteral(red: 0.2653386891, green: 0.2729498446, blue: 0.6093763709, alpha: 1)
                        icon = UIImage(named: "moon-icon")!
                    case 4:
                        let records = Array(patient!.weightRecords)
                        viewController.myRecords = records as [AnyObject]
                        title = "Weight Records"
                        color = #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1)
                        icon = UIImage(named: "weight-icon")!
                    case 5:
                        // 컨트롤러에 데이터 넘겨주는 듯?
                        let records = Array(patient!.hearthRecords)
                        viewController.myRecords = records as [AnyObject]
                        title = "Hearth BPM"
                        color = #colorLiteral(red: 0.9411764741, green: 0.4980392158, blue: 0.3529411852, alpha: 1)
                        icon = UIImage(named: "hearth-icon")!
                    default:
                        let records = Array(patient!.ingestedFoods)
                        viewController.myRecords = records as [AnyObject]
                        title = "Calories Consumed"
                        color = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
                        icon = UIImage(named: "food-icon")!
                    }
                    viewController.mainColor = color
                    viewController.mainIcon = icon
                    viewController.recordTitle = title
                }
            }
        } else if segue.identifier == "showEditProfileNC" {
            if let navigationController = segue.destination as? UINavigationController {
                if let viewController = navigationController.topViewController as? EditProfileViewController {
                    viewController.patient = self.patient
                }
            }
        }
    }
    
    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
        return CustomLayout()
    }
    
    func floatingPanel(_ vc: FloatingPanelController, behaviorFor newCollection: UITraitCollection) -> FloatingPanelBehavior? {
        return CustomBehaivor()
    }
    
}

class CustomLayout: FloatingPanelLayout {
    var initialPosition: FloatingPanelPosition {
        return .half
    }
    
    var supportedPositions: Set<FloatingPanelPosition> {
        return [.half, .hidden, .full, .tip]
    }
    
    var topInteractionBuffer: CGFloat { return 0.0 }
    var bottomInteractionBuffer: CGFloat { return 0.0 }
    
    func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        switch position {
        case .full: return 56.0
        case .half: return 350.0
        case .tip: return 85.0 + 44.0 // Visible + ToolView
        case .hidden: return nil
        }
    }
    
    func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat {
        return 0.0
    }
}


class CustomBehaivor: FloatingPanelBehavior {
    var velocityThreshold: CGFloat {
        return 15.0
    }
    
    func interactionAnimator(_ fpc: FloatingPanelController, to targetPosition: FloatingPanelPosition, with velocity: CGVector) -> UIViewPropertyAnimator {
        let timing = timeingCurve(to: targetPosition, with: velocity)
        return UIViewPropertyAnimator(duration: 0, timingParameters: timing)
    }
    
    private func timeingCurve(to: FloatingPanelPosition, with velocity: CGVector) -> UITimingCurveProvider {
        let damping = self.damping(with: velocity)
        return UISpringTimingParameters(dampingRatio: damping,
                                        frequencyResponse: 0.4,
                                        initialVelocity: velocity)
    }
    
    private func damping(with velocity: CGVector) -> CGFloat {
        switch velocity.dy {
        case ...(-velocityThreshold):
            return 0.7
        case velocityThreshold...:
            return 0.7
        default:
            return 1.0
        }
    }
}
