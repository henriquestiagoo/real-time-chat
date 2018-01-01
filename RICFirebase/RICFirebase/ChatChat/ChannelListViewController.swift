/*
 * Copyright (c) 2015 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import Firebase

enum Section: Int {
  case createNewChannelSection = 0
  case currentChannelsSection
}

class ChannelListViewController: UITableViewController {

  // MARK: Properties
  let listToUsers = "ListToUsers"
    
  var senderDisplayName: String?
  var newChannelTextField: UITextField?
  var user : User!
    
  var userCountBarButtonItem: UIBarButtonItem!
  
  private var channelRefHandle: FIRDatabaseHandle?
  private var channels: [Channel] = []

  // current channels
  private lazy var channelRef: FIRDatabaseReference = FIRDatabase.database().reference().child("channels")
    
  // online users
  let usersRef : FIRDatabaseReference = FIRDatabase.database().reference(withPath: "online")
  
  // MARK: View Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Channels"
    
    userCountBarButtonItem = UIBarButtonItem(title: "1",
                                             style: .plain,
                                             target: self,
                                             action: #selector(userCountButtonDidTouch))
    userCountBarButtonItem.tintColor = UIColor.white
    navigationItem.leftBarButtonItem = userCountBarButtonItem
    
    //let uidStr = String(describing: self.channelRef.childByAutoId())
    user = User(uid: self.senderDisplayName!, name: self.senderDisplayName!)
    
    FIRAuth.auth()!.addStateDidChangeListener { auth, user in
        
        print(self.user.uid)
        print(self.senderDisplayName!)
        
        // online users stuff
        let currentUserRef = self.usersRef.child(self.user!.uid)
        currentUserRef.setValue(self.user!.name)
        //let currentUserRef = self.usersRef.child(self.senderDisplayName!)
        //currentUserRef.setValue(self.senderDisplayName!)
        currentUserRef.onDisconnectRemoveValue()
    }
    
    // users observer
    usersRef.observe(.value, with: { snapshot in
        if snapshot.exists() {
            self.userCountBarButtonItem?.title = snapshot.childrenCount.description
        } else {
            self.userCountBarButtonItem?.title = "0"
        }
    })

    // channels observer
    observeChannels()
  }
  
  deinit {
    if let refHandle = channelRefHandle {
      channelRef.removeObserver(withHandle: refHandle)
    }
  }
  
  // MARK :Actions
    
    func userCountButtonDidTouch() {
        performSegue(withIdentifier: listToUsers, sender: nil)
    }
  
  @IBAction func createChannel(_ sender: AnyObject) {
    if let name = newChannelTextField?.text, name.count > 0 {
        var channelsNames : [String] = []
        for channel in channels {
            channelsNames.append(channel.name)
        }
        if !channelsNames.contains(name) {
            let newChannelRef = channelRef.childByAutoId()
            let channelItem = [
                "name": name
            ]

            newChannelRef.setValue(channelItem)
        } else {
            print("Error! Channel Exists... ")
            let alert = UIAlertController(title: "Duplicated Channel",
                                          message: "\(name) already exists ...",
                                          preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok",
                                             style: .default)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
        }
    } else {
        print("Error! Channel needs to have name... ")
        let alert = UIAlertController(title: "Channel without name",
                                      message: "Need to specify a name for a channel ...",
            preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok",
                                     style: .default)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
  }
  
  // MARK: Firebase related methods

  private func observeChannels() {
    // We can use the observe method to listen for new
    // channels being written to the Firebase DB
    //channelRefHandle = channelRef.observe(.childAdded, with: { (snapshot) -> Void in
    channelRefHandle = channelRef.observe(.value, with: { (snapshot) -> Void in
        
        var newChannels: [Channel] = []
        
        for item in snapshot.children {
            let channel = Channel(snapshot: item as! FIRDataSnapshot)
            if(channel.name.count > 0) {
                newChannels.append(channel)
            }else{
                print("NOPE == 0")
            }
        }
        self.channels = newChannels
        self.tableView.reloadData()
        
        /*
      let channelData = snapshot.value as! Dictionary<String, AnyObject>
      let id = snapshot.key
      if let name = channelData["name"] as! String!, name.characters.count > 0 {
        self.channels.append(Channel(id: id, name: name))
        self.tableView.reloadData()
      } else {
        print("Error! Could not decode channel data")
      }
         */
    })
  }
  
  // MARK: Navigation
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    super.prepare(for: segue, sender: sender)
    
    if let channel = sender as? Channel {
      let chatVc = segue.destination as! ChatViewController
      
      chatVc.senderDisplayName = senderDisplayName
      chatVc.channel = channel
      chatVc.channelRef = channelRef.child(channel.id)
    }
  }
  
  // MARK: UITableViewDataSource
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if let currentSection: Section = Section(rawValue: section) {
      switch currentSection {
      case .createNewChannelSection:
        return 1
      case .currentChannelsSection:
        return channels.count
      }
    } else {
      return 0
    }
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let reuseIdentifier = (indexPath as NSIndexPath).section == Section.createNewChannelSection.rawValue ? "NewChannel" : "ExistingChannel"
    let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)

    if (indexPath as NSIndexPath).section == Section.createNewChannelSection.rawValue {
      if let createNewChannelCell = cell as? CreateChannelCell {
        newChannelTextField = createNewChannelCell.newChannelNameField
      }
    } else if (indexPath as NSIndexPath).section == Section.currentChannelsSection.rawValue {
      cell.textLabel?.text = channels[(indexPath as NSIndexPath).row].name
    }
    
    return cell
  }

  // MARK: UITableViewDelegate
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if (indexPath as NSIndexPath).section == Section.currentChannelsSection.rawValue {
      let channel = channels[(indexPath as NSIndexPath).row]
      self.performSegue(withIdentifier: "ShowChannel", sender: channel)
    }
  }
    
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let channel = channels[indexPath.row]
            channel.ref?.removeValue()
        }
    }
  
}
