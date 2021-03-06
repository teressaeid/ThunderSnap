//
//  ChatViewController.swift
//  ThunderSnap
//
//  Created by blackbriar on 9/14/16.
//  Copyright © 2016 com.teressa. All rights reserved.
//

import UIKit
import AVKit
import Firebase
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var messages = [JSQMessage]()
    var avatars = [String: JSQMessagesAvatarImage]()
    var blankAvatarImage: JSQMessagesAvatarImage!
    var senderImageUrl: String!
    var chatId: String?
    var user: User?
    var url: String?
    var outgoingBubbleImageView: JSQMessagesBubbleImage!
    var incomingBubbleImageView: JSQMessagesBubbleImage!
    var incomingAvatar: JSQMessagesAvatarImage!
    var outgoingAvatar: JSQMessagesAvatarImage!
    
    
    let rootRef = FIRDatabase.database().referenceFromURL("https://mychat-7a248.firebaseio.com")
    var messagesRef: FIRDatabaseReference!
    var userIsTypingRef: FIRDatabaseReference!
    
    let imageView: UIImageView = {
        let iv = UIImageView(frame: CGRectMake(0, 0, 30, 30))
        iv.contentMode = .ScaleAspectFit
        iv.layer.cornerRadius = 5.0
        iv.layer.masksToBounds = true
        iv.userInteractionEnabled = true
        return iv
    }()
    private var localTyping = false
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    var usersTypingQuery: FIRDatabaseQuery!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ChatChat"
        setupBubbles()
        blankAvatarImage = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "profile_blank"), diameter: 30)
        self.incomingAvatar = blankAvatarImage
        self.outgoingAvatar = blankAvatarImage
        automaticallyScrollsToMostRecentMessage = true
    }
    
    private func setupBubbles() {
        let factory = JSQMessagesBubbleImageFactory()
        outgoingBubbleImageView = factory.outgoingMessagesBubbleImageWithColor(
            UIColor(hex: 0x0099E8))
        incomingBubbleImageView = factory.incomingMessagesBubbleImageWithColor(
            UIColor.jsq_messageBubbleLightGrayColor())
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        observeTyping()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(true)
        //        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapOnProfileImage(_:)))
        //        imageView.addGestureRecognizer(tap)
        imageView.loadImageFromUrl(url!)
        let imageItem = UIBarButtonItem(customView: imageView)
        navigationItem.rightBarButtonItem = imageItem
        getImages()
        ref?.child("users/\(currentUser!.uid)/partners/\(user!.uid!)").observeSingleEventOfType(.Value, withBlock: { (data) in
            if data.value is NSNull{
                let chatId = NSUUID().UUIDString
                self.chatId = chatId
                self.messagesRef = ref?.child("messages/\(self.chatId!)")
                self.observeForMessages()
            }
            else {
                guard let chatId = data.value as? String
                    else { fatalError("Why?") }
                self.chatId = chatId
                self.messagesRef = ref?.child("messages/\(self.chatId!)")
                self.observeForMessages()
            }
        })
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(collectionView: UICollectionView,
                                 cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
            as! JSQMessagesCollectionViewCell
        
        let message = messages[indexPath.item]
        print("MESSAGE is \(messages)")
        if !(messages[indexPath.item].isMediaMessage) {
            if message.senderId == senderId {
                cell.textView!.textColor = UIColor.whiteColor()
            } else {
                cell.textView!.textColor = UIColor.blackColor()
            }
        }
        return cell
    }
    

    
    func addMessage(id: String, text: String) {
        
        let message = JSQMessage(senderId: id, displayName: user!.username, text: text)
        messages.append(message)
    }
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!,
                                     senderDisplayName: String!, date: NSDate!) {
        
        sendMessageToServer(senderId, senderDisplayName: self.senderDisplayName, chatId: chatId!, message: text, user: user!)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()

        self.finishSendingMessage()
        
        isTyping = false

    }
    
    override func textViewDidChange(textView: UITextView) {
        super.textViewDidChange(textView)
        // If the text is not empty, the user is typing
         isTyping = textView.text != ""
    }
    
    
    
    override func didPressAccessoryButton(sender: UIButton!) {
        selectImage()
    }
    
    private func selectImage() {
        let alertController = UIAlertController(title: "Where do you want to get your picture from?", message: nil, preferredStyle: .ActionSheet)
        let cameraAction = UIAlertAction(title: "Photo from Camera", style: .Default) { (UIAlertAction) -> Void in
            self.selectFromCamera()
        }
        let libraryAction = UIAlertAction(title: "Photo from Library", style: .Default) { (UIAlertAction) -> Void in
            self.selectFromLibrary()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (UIAlertAction) -> Void in
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        alertController.addAction(cameraAction)
        alertController.addAction(libraryAction)
        alertController.addAction(cancelAction)
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    private func selectFromCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = UIImagePickerControllerSourceType.Camera
            imagePickerController.allowsEditing = true
            self.presentViewController(imagePickerController, animated: true, completion: nil)
        } else {
            print("Error cannot access camera. Check permissions maybe?")
        }
    }
    
    private func selectFromLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.PhotoLibrary) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
            imagePickerController.allowsEditing = true
            self.presentViewController(imagePickerController, animated: true, completion: nil)
        } else {
            print("Error cannot access camera. Check permissions maybe?")
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        print("picked image")
        print(info)
        if let picture = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.sendMedia(picture, video: nil)
        }
        if let video = info[UIImagePickerControllerMediaURL] as? NSURL {
            self.sendMedia(nil, video: video)
        }
        self.dismissViewControllerAnimated(true, completion: nil)
        collectionView.reloadData()
    }
    
    func getImages() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let userData = NSData(contentsOfURL: NSURL(string:(self.senderImageUrl)!)!) //make sure your image in this url does exist, otherwise unwrap in a if let check
//            dispatch_async(dispatch_get_main_queue(), {
//                self.outgoingAvatar = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(data: userData!), diameter: 64)
//            })
            self.outgoingAvatar = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(data: userData!), diameter: 64)
            let data = NSData(contentsOfURL: NSURL(string:(self.url)!)!)
            self.incomingAvatar = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(data: data!), diameter: 64)
            self.collectionView.reloadData()
        }
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
//            let data = NSData(contentsOfURL: NSURL(string:(self.url)!)!) //make sure your image in this url does exist, otherwise unwrap in a if let check
//            dispatch_async(dispatch_get_main_queue(), {
//                self.incomingAvatar = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(data: data!), diameter: 64)
//            })
//        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return self.outgoingAvatar
        }
        return self.incomingAvatar
    }
    
    

    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        if indexPath.item % 10 == 0 {
            return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(messages[indexPath.item].date)
        }
        
        return nil
    }
    /* Handle tap on a media item
     */
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAtIndexPath indexPath: NSIndexPath!) {
        print("didTapMessageBubbleAtIndexPath \(indexPath.item)")
        let message = messages[indexPath.item]
        
        if message.isMediaMessage {
            if let mediaItem = message.media as? JSQVideoMediaItem {
                //print("MEssage is a video")
                let player = AVPlayer(URL: mediaItem.fileURL)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                self.presentViewController(playerViewController, animated: true, completion: nil)
            }
            else if let mediaItem = message.media as? JSQPhotoMediaItem {
                //print("MEssage is a PHOTO")
                self.popUptoScreen(mediaItem.image)
                
            }
        }
    }
    
    /* Helper function to create a popup for the images
    */
    
    func popUptoScreen(image: UIImage) {
        let newImageView = UIImageView(image: image)
        newImageView.frame = self.view.frame
        newImageView.backgroundColor = .blackColor()
        newImageView.contentMode = .ScaleAspectFit
        newImageView.userInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(ChatViewController.dismissFullscreenImage(_:)))
        newImageView.addGestureRecognizer(tap)
        self.view.addSubview(newImageView)
    }
    
    func dismissFullscreenImage(sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    /*
        MARK - Firebase methods for observing and sending data to the server
     */
    
    private func observeTyping() {
        let typingIndicatorRef = rootRef.child("typingIndicator")
        userIsTypingRef = typingIndicatorRef.child(senderId)
        userIsTypingRef.onDisconnectRemoveValue()
        
        usersTypingQuery = typingIndicatorRef.queryOrderedByValue().queryEqualToValue(true)
        usersTypingQuery.observeEventType(.Value, withBlock: { snapshot in
            // You're the only one typing, don't show the indicator
            print("YOU ARE THE ONLY ONE")
            if snapshot.childrenCount == 1 && self.isTyping { return }
            
            // Are there others typing?
            self.showTypingIndicator = snapshot.childrenCount > 0
            self.scrollToBottomAnimated(true)
        })
    }
    
    func observeForMessages() {
        messagesRef?.observeEventType(.ChildAdded, withBlock: { (snapshot) in
            if snapshot.value is NSNull{
                print("No messages :(")
            }
            else {
            print("THERE ARE MESSGAES")
            print(snapshot.value!)
                if let id = snapshot.value!["senderId"] as? String, let senderName = snapshot.value!["senderName"] as? String, let mediaType = snapshot.value!["MediaType"] as? String, let createdDate = snapshot.value!["createdDate"] as? NSNumber {
                    var formattedDate = NSDate()
                    //let imageUrl = snapshot.value!["imageUrl"] as? String
                    if let createdDate = createdDate as? NSTimeInterval{
                        formattedDate = NSDate(timeIntervalSince1970: createdDate/1000)
                    }
                    //print(snapshot.value!)
                    switch mediaType {
                    case "TEXT":
                        let text = snapshot.value!["text"] as! String
                        self.messages.append(JSQMessage(senderId: id, senderDisplayName: senderName, date: formattedDate, text: text))
                    case "PHOTO":
                        let fileUrl = snapshot.value!["fileUrl"]  as! String
                        let storageRef = FIRStorage.storage()
                        /// not used for now
                        let filePath = "\(id)/media/\(fileUrl)"
                        // Assuming a < 10MB file, though you can change that
                        storageRef.referenceForURL(fileUrl).dataWithMaxSize(10*1024*1024, completion: { (data, error) in
                            //print("FOUND Picture")
                            let picture = UIImage(data: data!)
                            let photo = JSQPhotoMediaItem(image: picture)
                            self.messages.append(JSQMessage(senderId: id, senderDisplayName: senderName, date: formattedDate, media: photo))
                        //self.messages.append(JSQMessage(senderId: id, displayName: senderName, media: photo))
                            if self.senderId == id {
                                photo.appliesMediaViewMaskAsOutgoing = true
                            } else {
                                photo.appliesMediaViewMaskAsOutgoing = false
                            }
                            self.messages.sortInPlace{$0.date.compare($1.date) == .OrderedAscending}
                            self.collectionView.reloadData()
                        })
                    case "VIDEO":
                        let fileUrl = snapshot.value!["fileUrl"] as! String
                        let video = NSURL(string: fileUrl)
                        let videoItem = JSQVideoMediaItem(fileURL: video, isReadyToPlay: true)
                        self.messages.append(JSQMessage(senderId: id, senderDisplayName: senderName, date: formattedDate, media: videoItem))
                        
                        if self.senderId == id {
                            videoItem.appliesMediaViewMaskAsOutgoing = true
                        } else {
                            videoItem.appliesMediaViewMaskAsOutgoing = false
                        }
                    default:
                        print("Invalid data type")
                    }
                    self.finishReceivingMessage()
                }
            }
        })
    }
    
    func sendMessageToServer(sender: String, senderDisplayName: String, chatId: String, message: String, user: User) {
        ref?.child("users/\(currentUser!.uid)/partners/\(user.uid!)").observeSingleEventOfType(.Value, withBlock: { (snapshot) in
            if snapshot.value is NSNull{
                let messageRef = ref?.child("messages/\(chatId)").childByAutoId()
                let messageValue = [
                    "text": message,
                    "senderId": sender,
                    "senderName": senderDisplayName,
                    "MediaType": "TEXT",
                    "createdDate": FIRServerValue.timestamp()
                ]
                let chatData = [
                    "chatId": chatId,
                    "user1": user.uid!,
                    "user2": currentUser!.uid,
                    "lastMessageDate": FIRServerValue.timestamp(),
                    "lastMessage": message
                ]
                ref?.child("chats/\(chatId)").setValue(chatData)
                ref?.child("users/\(currentUser!.uid)/partners/\(user.uid!)").setValue(chatId)
                ref?.child("users/\(user.uid!)/partners/\(currentUser!.uid)").setValue(chatId)
                ref?.child("users/\(currentUser!.uid)/chats/\(chatId)").setValue(chatData)
                ref?.child("users/\(user.uid!)/chats/\(chatId)").setValue(chatData)
                messageRef?.setValue(messageValue)
            }
            else {
                let messageRef = ref?.child("messages/\(chatId)").childByAutoId()
                let messageValue = [
                    "text": message,
                    "senderId": sender,
                    "senderName": senderDisplayName,
                    "MediaType": "TEXT",
                    "createdDate": FIRServerValue.timestamp()
                ]
                let chatData = [
                    "lastMessageDate": FIRServerValue.timestamp(),
                    "lastMessage": message
                ]
                
                ref?.child("chats/\(chatId)").updateChildValues(["lastMessageDate": FIRServerValue.timestamp(), "lastMessage": message])
                ref?.child("users/\(currentUser!.uid)/chats/\(chatId)").updateChildValues(chatData as! [String: AnyObject])
                ref?.child("users/\(user.uid!)/chats/\(chatId)").updateChildValues(chatData as! [String: AnyObject])
                messageRef?.setValue(messageValue)
            }
        })
    }
    
    func sendMedia(picture: UIImage?, video: NSURL?) {
        
        if let picture = picture {
            //let filepath = "\(FIRAuth.auth()!.currentUser!.uid)/\(NSDate.timeIntervalSinceReferenceDate())"
            let filepath = "\(FIRAuth.auth()!.currentUser!.uid)/media/"
            let data = UIImageJPEGRepresentation(picture, 0.1)
            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpg"
            FIRStorage.storage().reference().child(filepath).putData(data!, metadata: metadata) { (metadata, error) in
                if error != nil {
                    print(error?.localizedDescription)
                }
                
                let fileUrl = metadata!.downloadURLs![0].absoluteString
                print("final path is \(fileUrl)")
                let path = FIRStorage.storage().reference().child(filepath).fullPath
                print("FULL PATH IS \(path)")
                
                let newMessage = ref?.child("messages/\(self.chatId!)").childByAutoId()
                let messageData = [
                    "fileUrl": fileUrl,
                    "senderId":self.senderId,
                    "senderName":self.senderDisplayName,
                    "MediaType":"PHOTO",
                    "createdDate": FIRServerValue.timestamp()]
                newMessage?.setValue(messageData)
                
            }
        } else if let video = video {
            let filepath = "\(FIRAuth.auth()!.currentUser!.uid)/\(NSDate.timeIntervalSinceReferenceDate())"
            let data = NSData(contentsOfURL: video)
            let metadata = FIRStorageMetadata()
            metadata.contentType = "video/mp4"
            FIRStorage.storage().reference().child(filepath).putData(data!, metadata: metadata) { (metadata, error) in
                if error != nil {
                    print(error?.localizedDescription)
                }
                
                let fileUrl = metadata!.downloadURLs![0].absoluteString
                
                let newMessage = ref?.child("messages/\(self.chatId!)").childByAutoId()
                let messageData = [
                    "fileUrl": fileUrl,
                    "senderId":self.senderId,
                    "senderName":self.senderDisplayName,
                    "MediaType":"VIDEO",
                    "createdDate": FIRServerValue.timestamp()]
                newMessage?.setValue(messageData)
                
            }
        }
    }

    
}