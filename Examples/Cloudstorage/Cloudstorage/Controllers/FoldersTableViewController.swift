//
//  FoldersTableViewController.swift
//  Cloudstorage
//
//  Created by Mujtaba Alam on 06.06.17.
//  Copyright © 2017 CloudRail. All rights reserved.
//

import UIKit
import CloudrailSI
import Toast_Swift
import WebKit

class FoldersTableViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var menuBarButton: UIBarButtonItem!
    
    private let activityIndicator = UIActivityIndicatorView()
    
    private let refresh = UIRefreshControl()
    
    private let picker = UIImagePickerController()
    
    var cloudStorageTitle: String?
    var cloudStorageType: String?
    
    //CloudStorageProctocol that you want to use e.g Dropxbox, Box, Google Drive, One Drive or Egnyte
    private var cloudStorage: CloudStorageProtocol?
    
    private var storageService: CRPersistableProtocol?
    
    //CloudMetaData is retrived
    private var data = [CRCloudMetaData]()
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"", style:.plain, target:nil, action:nil)
        
        Helpers.showSideMenu(menuBarButton, self)
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        self.navigationItem.title = cloudStorageTitle
        
        picker.delegate = self
        
        //Refresh Controller
        
        if #available(iOS 10.0, *) {
            self.tableView.refreshControl = refresh
        } else {
            self.tableView.addSubview(refresh)
        }
        
        refresh.addTarget(self, action: #selector(reloadRetivedData), for: .valueChanged)
        
        //Setup service you want to use
        setupService()
    }
    
    // MARK: - Setup Service (Dropbox, Box, GoogleDrive, One Drive or Egnyte)
    //More information: https://cloudrail.com/integrations/interfaces/CloudStorage;platformId=Swift
    
    func setupService() {
        
        //Note: These are sample Keys/Secrets for example purpose, do not use it in live production
        
        if cloudStorageType == "dropbox" {
            
            //Dropbox service needs Key / Secret
            //Note: - useAdvancedAuthentication() For Google Login with the RedirectURI constructor
            
            let drive = Dropbox(clientId: "38nu3lwdvyaqs78", clientSecret: "c95g0wfkdv6ua2d")
            cloudStorage = drive
            
        } else if cloudStorageType == "box" {
            //Box service needs Key / Secret
            cloudStorage = Box(clientId: "qnskodzvd2naq16xowc40t43fug2848n", clientSecret: "cQE7Sf9DzZqChjvCTxIMTp3ye6hynhTd")
            
        } else if cloudStorageType == "googleDrive" {
            
            //Google Drive is unique as it needs the following:
            //1. API Key (no secret required)
            //2. Redirect URI and a State (any)
            //3. useAdvancedAuthentication() method Must be called!
            
            let drive = GoogleDrive(clientId: "1007170750392-0ikqfi754e8bkuua26098193frl07nle.apps.googleusercontent.com",
                                    clientSecret: "",
                                    redirectUri: "org.cocoapods.demo.CloudRail-SI-iOS.Cloudstorage:/oauth2redirect",
                                    state: "efwegwww")
            
            drive.useAdvancedAuthentication()
            cloudStorage = drive
            
        } else if cloudStorageType == "oneDrive" {
            
            cloudStorage = OneDrive(clientId: "000000004018F12F", clientSecret: "lGQPubehDO6eklir1GQmIuCPFfzwihMo", redirectUri: "https://www.cloudrailauth.com/auth", state: "STATE", scopes: [])
            
        } else if cloudStorageType == "egnyte" {
            
            //Egnyte requires the following:
            //1. Domain
            //2. API Key
            //3. Secret
            //4. Redirect URI and a State (any)
            
            cloudStorage = Egnyte(domain: "cloudrailcloudtest",
                             clientId: "k9y879bha2kmsyyqx4urtnaz",
                             clientSecret: "TsgByd2YZqsJPyYMDhEB6ctAYQ6kP35qYTnEG9urPKq2eNNXRF",
                             redirectUri: "https://www.cloudrailauth.com/auth",
                             state: "STATE")
        }
        
        //Load Saved Service
        
        guard let result = UserDefaults.standard.value(forKey: self.cloudStorageType!) else {
            retriveFilesFoldersData(true)
            return
        }
        
        if !String(describing: result).isEmpty {
            CloudStorageLogic.loadAsString(cloudStorage: cloudStorage!, savedState: result as! String)
        }
        
        //Retrieve Data
        retriveFilesFoldersData(true)
    }
    
    // MARK: - Retrieve Data
    
    func reloadRetivedData() {
        retriveFilesFoldersData(true)
    }
    
    func retriveFilesFoldersData(_ showIndicator: Bool) {
        
        if refresh.isEnabled {
            self.tableView.isUserInteractionEnabled = false
        }
        
        if showIndicator {
            self.startActivityIndicator()
        }
        
        let backgroundQueue = DispatchQueue(label: "com.cloudrailapp.queue",
                                            qos: .background,
                                            target: nil)
        backgroundQueue.async {
            
            self.data = CloudStorageLogic.childrenOfFolderWithPath(cloudStorage: self.cloudStorage!,
                                                                   path: "/") as! [CRCloudMetaData]
            self.stopActivityIndicator()
            print(self.data)
            
            //Persistent data - Save Service
            let savedString = CloudStorageLogic.saveAsString(cloudStorage: self.cloudStorage!)
            UserDefaults.standard.set(savedString, forKey: self.cloudStorageType!)
            
            DispatchQueue.main.async {
                self.tableView.isUserInteractionEnabled = true
                if self.refresh.isEnabled {
                    self.refresh.endRefreshing()
                }
                self.tableView.reloadData()
            }
            
        }
    }
    
    // MARK: - Upload File
    @IBAction func uploadFileAction(_ sender: Any) {
        
        let alertController = UIAlertController(title: "Upload File", message: "Upload Photos, Docs to Cloud Storage", preferredStyle: .actionSheet)
        
        let cameraButton = UIAlertAction(title: "Take a Photo", style: .default, handler: { (action) -> Void in
            self.picker.allowsEditing = false
            self.picker.sourceType = UIImagePickerControllerSourceType.camera
            self.picker.cameraCaptureMode = .photo
            self.picker.modalPresentationStyle = .fullScreen
            self.present(self.picker,animated: true,completion: nil)
        })
        
        let photoButton = UIAlertAction(title: "Choose a Photo", style: .default, handler: { (action) -> Void in
            
            self.picker.allowsEditing = false
            self.picker.sourceType = .photoLibrary
            self.picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
            self.present(self.picker, animated: true, completion: nil)
            
        })
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(cameraButton)
        alertController.addAction(photoButton)
        alertController.addAction(cancelButton)
        
        self.navigationController!.present(alertController, animated: true, completion: nil)
    }
    
    
    // MARK: - Search
    
    @IBAction func searchAction(_ sender: Any) {
        let alertController = UIAlertController(title: "Feature Coming Soon", message: "Search Cloudstorage feature coming soon", preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(cancelButton)
        
        self.navigationController!.present(alertController, animated: true, completion: nil)
        
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! FoldersCell
        
        let cloudMetaData = self.data[indexPath.row]
        cell.folderLbl.text = cloudMetaData.name
        cell.folderImgView.image = Helpers.imageType(cloudMetaData)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cloudMetaData = self.data[indexPath.row]
        
        if Helpers.isImage(cloudMetaData) {
            self.performSegue(withIdentifier: "ImageSegue", sender: indexPath)
        } else {
            
            if Helpers.isFolder(cloudMetaData) {
                self.performSegue(withIdentifier: "SubFolderSegue", sender: indexPath)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let cloudMetaData = self.data[indexPath.row]
        
        let delete = UITableViewRowAction(style: .normal, title: "Delete") { action, index in
            
            let alertController = UIAlertController(title: "Delete", message: "Do you want to delete this file or folder?", preferredStyle: .alert)
            
            let deleteButton = UIAlertAction(title: "Delete", style: .destructive, handler: { (action) -> Void in
                
                if CloudStorageLogic.deleteFileWithPath(cloudStorage: self.cloudStorage!, path: cloudMetaData.path) {
                    self.retriveFilesFoldersData(false)
                }
                self.tableView.reloadData()
                
            })
            
            let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) -> Void in
                self.tableView.reloadData()
            })
            
            alertController.addAction(deleteButton)
            alertController.addAction(cancelButton)
            self.navigationController!.present(alertController, animated: true, completion: nil)
            
        }
        delete.backgroundColor = UIColor.FlatColor.Red.Valencia
        
        let share = UITableViewRowAction(style: .normal, title: "Share") { action, index in
            
            guard let link = CloudStorageLogic.shareLinkForFileWithPath(cloudStorage: self.cloudStorage!, path: cloudMetaData.path) else {
                return
            }
            
            UIPasteboard.general.string = link
            
            self.view.makeToast("Link copied to clipboard", duration: 3.0, position: .bottom)
            self.tableView.reloadData()
        }
        share.backgroundColor = UIColor.FlatColor.Blue.Denim
        
        
        let download = UITableViewRowAction(style: .normal, title: "Download") { action, index in
            
            self.view.makeToast("Downloading file", duration: 3.0, position: .top)
            let backgroundQueue = DispatchQueue(label: "com.cloudrail.queue",
                                                qos: .background,
                                                target: nil)
            backgroundQueue.async {
                self.tableView.reloadData()
                if let result = CloudStorageLogic.downloadFileWithPath(cloudStorage:self.cloudStorage!, path: cloudMetaData.path) {
                    Helpers.downloadFileToDoc(inputStream: result, name: cloudMetaData.name)
                }
            }
            
            self.view.makeToast("File saved", duration: 2.0, position: .top)
        }
        download.backgroundColor = UIColor.FlatColor.Green.ChateauGreen
        
        if !Helpers.isFolder(cloudMetaData) && !Helpers.isImage(cloudMetaData) {
            return [download, share, delete]
        } else {
            return [share, delete]
        }
        
    }
    
    // MARK: - Image Picker
    
    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        self.dismiss(animated: true, completion: nil)
        
        //Always run this on background thread
        self.view.makeToast("Uploading image", duration: 3.0, position: .top)
        let backgroundQueue = DispatchQueue(label: "com.cloudrailapp.queue",
                                            qos: .background,
                                            target: nil)
        backgroundQueue.async {
            
            let chosenImage = info[UIImagePickerControllerOriginalImage] as! UIImage
            if let data:Data = UIImageJPEGRepresentation(chosenImage,1) {
                let inputStream = InputStream.init(data: data)
                
                //Randome image name
                let path = "/\(Helpers.randomImageName())"
                
                if CloudStorageLogic.uploadFileToPath(cloudStorage: self.cloudStorage!, path: path, inputStream: inputStream, size: data.count) {
                    self.view.makeToast("Image uploaded", duration: 2.0, position: .top)
                    self.retriveFilesFoldersData(false)
                }
            }
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : Any]!) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let indexPath = (sender as! IndexPath)
        let cloudMetaData = self.data[indexPath.row]
        
        if segue.identifier == "ImageSegue" {
            let details = (segue.destination as! ImageViewController)
            details.cloudStorage = self.cloudStorage
            details.cloudMetaData = cloudMetaData
        } else if segue.identifier == "SubFolderSegue" {
            let details = (segue.destination as! SubFoldersTableViewController)
            details.cloudStorage = self.cloudStorage
            details.path = cloudMetaData.path
        } else if segue.identifier == "SearchSegue" {
            let details = (segue.destination as! SearchTableViewController)
            details.cloudStorage = self.cloudStorage
        }
    }
    
}