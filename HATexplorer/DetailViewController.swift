//
//  DetailViewController.swift
//  HATexplorer
//
//  Created by David Jensenius on 2015-07-22.
//  Copyright (c) 2015 David Jensenius. All rights reserved.
//

import UIKit
import MapKit
import AVFoundation

class DetailViewController: UIViewController, CLLocationManagerDelegate, AVAudioPlayerDelegate {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    
    @IBOutlet weak var loadingActivitySpinner: UIActivityIndicatorView!
    @IBOutlet weak var gameDescription: UITextView!
    
    let downloadURL = "https://mld.jensenius.org/download/"
    
    let locationManager = CLLocationManager()
    var currentLocation = CLLocation()
    var currentLon = Double()
    var currentLat = Double()
    var layers = NSArray()
    var currentGame = NSDictionary()
    
    var bytes: NSMutableData?
    
    var firstLoop = true
    var loaded = false
    var inGameArea = false
    var inPolygon = false
    
    var offsetLng:Double = 0
    var offsetLat:Double = 0
    
    var loader: NSURLSession?
    var downloadCount = 0
    
    var currentEvent = NSString()
    
    dynamic var identityPlayers = NSMutableDictionary()
    dynamic var identityPlayerItems = NSMutableDictionary()
    dynamic var eventPlayers = NSMutableDictionary()
    dynamic var eventPlayerItems = NSMutableDictionary()
    var eventDebug = NSMutableDictionary()
    var identityDebug = NSMutableDictionary()
    var gameLoader = NSTimer()
    
    let userDefaults = NSUserDefaults.standardUserDefaults()
    

    var detailItem: AnyObject? {
        didSet {
            // Update the view.
            self.configureView()
            print("Detail item is set... \(detailItem)")
        }
    }

    func configureView() {
        // Update the user interface for the detail item.
        if let detail: AnyObject = self.detailItem {
            if let label = self.detailDescriptionLabel {
                label.text = "Loading Game"
                self.title = detail.objectForKey("title") as? String
                print("Set title to \(self.title)")
                loadGame()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
        self.gameDescription.hidden = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        do {
            // Background sound
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        } catch _ {
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch _ {
        }
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        
        //loadGame()
        
        //Let's reload game data every 10 seconds
        gameLoader = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: #selector(DetailViewController.loadGame), userInfo: nil, repeats: true)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(DetailViewController.stopEverything), name: "stopEverything", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(DetailViewController.restartEverything), name: "restartEverything", object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        //Stop everything
        stopEverything()
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLat = manager.location!.coordinate.latitude - offsetLat
        currentLon = manager.location!.coordinate.longitude - offsetLng
        currentLocation = CLLocation(latitude: currentLat, longitude: currentLon)
        
        print("I have a location and I am loading more stuff")
        if (loaded == true) {
            checkStates()
        }
    }
    
    func checkStates() {
        var leastDistance = 1000000000000.1
        if (firstLoop == true) {
            print("First loop, checking to see if we are in range")
            for layer in layers {
                //var layerTitle = layer["title"] as! NSString
                //println("Checking layer: \(layerTitle)")
                
                let zones = layer["zone"] as! NSArray
                for zone in zones {
                    let zoneTitle = zone["title"] as! NSString
                    
                    if (inGameArea == false) {
                        let polygon = zone["polygon"] as! NSArray
                        print("Checking zone \(zoneTitle)")
                        if (insidePolygon(polygon)) {
                            inGameArea = true
                            inPolygon = true
                        }
                        
                        let distance = distanceFromPolygon(polygon)
                        if (distance < leastDistance) {
                            leastDistance = distance
                        }
                    }
                    
                    let identity = zone["identity"] as! NSDictionary
                    checkFiles(identity["file"] as! NSArray)
                    
                    let event = zone["event"] as! NSDictionary
                    checkFiles(event["file"] as! NSArray)
                    
                    //println("Identity is \(identity) ")
                }
            }
            //For now, if we are a kilometer away from the nearest sound, we will bail and set offsets
            if currentGame["longitude"] != nil {
                if (leastDistance > 1000) {
                    offsetLng = currentLon - (currentGame["longitude"] as! Double)
                    offsetLat = currentLat - (currentGame["latitude"] as! Double)
                    print("We are offsetting by \(offsetLat), \(offsetLng)")
                } else {
                    offsetLat = 0
                    offsetLng = 0
                    print("No offsetting needed")
                }
            }
            
            firstLoop = false
        } else if downloadCount == 0 {
            print("Regular loop")
            //Let's get sounds playing!
            self.detailDescriptionLabel.hidden = true
            self.loadingActivitySpinner.hidden = true
            self.gameDescription.hidden = false
            
            for layer in layers {
                //var layerTitle = layer["title"] as! NSString
                //println("Checking layer: \(layerTitle)")
                
                let zones = layer["zone"] as! NSArray
                for zone in zones {
                    //var zoneTitle = zone["title"] as! NSString
                    let id = zone["_id"] as! NSString
                    let polygon = zone["polygon"] as! NSArray
                    //println("Checking zone \(zoneTitle)")
                    if (insidePolygon(polygon)) {
                        inPolygon = true
                        currentEvent = id;
                        //println("In polygon")
                    } else if (currentEvent == id) {
                        currentEvent = ""
                        //println("Removed from polygon")
                    } else {
                        //println("Not in polygon")
                    }
                    
                    let distance = distanceFromPolygon(polygon)
                    if (distance < leastDistance) {
                        leastDistance = distance
                    }
                    
                    let identity = zone["identity"] as! NSDictionary
                    let event = zone["event"] as! NSDictionary
                    let zt = zone["title"] as! NSString
                    var sensitivity:Float = 0.0
                    if (identity["sensitivity"] != nil) {
                        sensitivity = identity["sensitivity"] as! Float
                    }
                    
                    setSound(id, identity: identity, event: event, polygon: currentEvent, distance: distance, sensitivity: sensitivity, zoneTitle: zt)
                }
            }
        }
    }
    
    func setSound(zoneId:NSString, identity:NSDictionary, event:NSDictionary, polygon:NSString, distance:Double, sensitivity:Float, zoneTitle:NSString) {
        //Check to see if sound is created, if not, create it
        //If the sound is in a polygon, start event and mute all others
        print("Setting sound?")
        if (identityPlayers.objectForKey(zoneId) == nil && eventPlayers.objectForKey(zoneId) == nil) {
            //Create item!
            print("Having to create?")
            //loop through both identity and event files, grab the last one and set it to play: FIX LATER
            
            let cachePath = cacheSoundDirectoryName()
            var hasIdentitySound = false
            let files:NSArray = identity["file"] as! NSArray
            var identityURL = NSURL()
            for file in files {
                let currentFile = file as! NSDictionary
                let fileid = currentFile["_id"] as! NSString
                let ext = (currentFile["title"] as! NSString).pathExtension
                let fileCheck = "\(fileid).\(ext)"
                identityURL = NSURL(fileURLWithPath: cachePath.stringByAppendingPathComponent(fileCheck))
                hasIdentitySound = true
            }
            
            
            if hasIdentitySound == true {
                identityPlayers.setObject(try! AVAudioPlayer(contentsOfURL: identityURL), forKey: zoneId)
                (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).numberOfLoops = -1
                (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
                (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).play()
            }
            
            let eventFiles:NSArray = event["file"] as! NSArray
            //println("Event files \(eventFiles)")
            var eventURL = NSURL()
            var hasEventSound = false
            for file in eventFiles {
                let currentFile = file as! NSDictionary
                let fileid = currentFile["_id"] as! NSString
                let ext = (currentFile["title"] as! NSString).pathExtension
                let fileCheck = "\(fileid).\(ext)"
                eventURL = NSURL(fileURLWithPath: cachePath.stringByAppendingPathComponent(fileCheck))
                hasEventSound = true
            }
            
            if hasEventSound == true {
                eventPlayers.setObject(try! AVAudioPlayer(contentsOfURL: eventURL), forKey: zoneId)
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).numberOfLoops = -1
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).play()
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).pause()
                print("Setting event sound... and pausing")
            }
        }
        
        if polygon != "" {
            if eventPlayers.objectForKey(polygon) != nil {
                (eventPlayers.objectForKey(polygon) as! AVAudioPlayer).play()
                (eventPlayers.objectForKey(polygon) as! AVAudioPlayer).volume = 1.0
                print("Event sound now plays")
            }
            if (zoneId != polygon) {
                if eventPlayers.objectForKey(zoneId) != nil {
                    (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).pause()
                    (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
                }
            }
            if identityPlayers.objectForKey(zoneId) != nil {
                (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
            }
            
        } else {
            //Set volume!
            //Make sure all events are muted then set other volumes
            if (eventPlayers.objectForKey(zoneId) != nil) {
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).pause()
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
                //println("Event not nil")
            }
            
            var distanceFrom = Float()
            userDefaults.synchronize()
            var formula = NSString()
            if let useLog: AnyObject = userDefaults.objectForKey("logIdentity") {
                print(useLog);
                if (useLog as! Bool == true) {
                    //Logorithmic growth
                    //println("Logorithmic growth!")
                    distanceFrom = 1 + log(Float(distance / 1000))
                    formula = "1 + log(Float(\(distance) / 1000))"
                    
                } else {
                    //Normal growth
                    //println("Normal growth!")
                    distanceFrom = 1 + Float(distance / 1000)
                    formula = "1 + Float(\(distance) / 1000)"
                }
            } else {
                //Normal growth
                //println("Normal growth!")
                distanceFrom = 1 + Float(distance / 1000)
                formula = "1 + Float(\(distance) / 1000)"
            }
            
            if (distanceFrom < 0) {
                distanceFrom = 0
            }
            
            //println("Actual distance: \(distance)")
            //var volume:Float = 1.0 - (distanceFrom * sensitivity)
            var volume:Float = (1.0 - (distanceFrom * (sensitivity + 1.0)))
            formula = "1.0 - ((\(formula)) * (\(sensitivity) + 1.0))"
            if (volume < 0) {
                volume = 0
            }
            //println("Setting volume to \(volume)")
            if (identityPlayers.objectForKey(zoneId) != nil) {
                (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = volume
            }
            let debugText = "\(zoneTitle)\nDistance - \(distance)\nAdjusted Value - \(distanceFrom)\nVolume - \(volume)\n\(formula)"
            //println(debugText)
            identityDebug.setObject(debugText, forKey: zoneId)
            
        }
    }
    
    func playerItemDidReachEnd(notification: NSNotification) {
        print("Looping?? \(notification.object)")
        let p:AVPlayerItem  = notification.object as! AVPlayerItem
        p .seekToTime(kCMTimeZero)
    }
    
    func insidePolygon(polygons:NSArray) -> Bool {
        //http://web.archive.org/web/20080812141848/http://local.wasp.uwa.edu.au/~pbourke/geometry/insidepoly/
        //http://stackoverflow.com/questions/25835985/determine-whether-a-cllocationcoordinate2d-is-within-a-defined-region-bounds
        //println("Checking polygon \(polygons)")
        
        var  polyCoords:Array<CLLocationCoordinate2D> = []
        
        for i in 0 ..< polygons.count {
            let polygon = polygons[i] as! NSDictionary
            //let curLat = polygon["latitude"] as! CLLocationDegrees
            polyCoords.append(CLLocationCoordinate2DMake(polygon["latitude"] as! CLLocationDegrees, polygon["longitude"] as! CLLocationDegrees))
        }
        
        let mpr:CGMutablePathRef = CGPathCreateMutable()
        
        for i in 0 ..< polyCoords.count {
            let c:CLLocationCoordinate2D = polyCoords[i]
            
            if (i == 0) {
                CGPathMoveToPoint(mpr, nil, CGFloat(c.longitude), CGFloat(c.latitude))
            } else {
                CGPathAddLineToPoint(mpr, nil, CGFloat(c.longitude), CGFloat(c.latitude))
            }
        }
        let testCGPoint:CGPoint = CGPointMake(CGFloat(currentLon), CGFloat(currentLat))
        let inPolygon:Bool = CGPathContainsPoint(mpr, nil, testCGPoint, false);
        
        //println("Are we in the polygon \(inPolygon)")
        return inPolygon
    }
    
    func distanceFromPolygon(polygon:NSArray) -> Double {
        var distance = 100000000000000000.1
        
        for coords in polygon {
            //let location = coords as! NSDictionary
            let pointLocation = CLLocation(latitude: coords["latitude"] as! CLLocationDegrees, longitude: coords["longitude"] as! CLLocationDegrees)
            let distanceFrom = pointLocation.distanceFromLocation(currentLocation)
            if (distanceFrom < distance) {
                distance = distanceFrom
            }
        }
        
        //println("We are this far away: \(distance)")
        return distance
    }
    
    func checkFiles(files:NSArray) {
        // Check to see if file is in our local cache, if not, check to see if it is in the application, if not, download!
        let cachePath = cacheSoundDirectoryName()
        
        for file in files {
            let theFile = file as! NSDictionary
            let fileName = theFile.objectForKey("title")! as! NSString
            print("The file is \(fileName)")
            //let fileURL = NSURL(string: fileName)
            let ext = fileName.pathExtension
            let fileid = theFile["_id"] as! NSString
            //let filename = theFile["title"] as! NSString
            
            let fileCheck = "\(fileid).\(ext)"
            if NSFileManager.defaultManager().fileExistsAtPath(cachePath.stringByAppendingPathComponent(fileCheck)) {
                print("File exists in cache")
            } else {
                let resourceExists = NSBundle.mainBundle().pathForResource(fileid as String, ofType: ext)
                if ((resourceExists) != nil) {
                    print("Resource in bundle")
                    let fileManager = NSFileManager.defaultManager()
                    let copyTo = "\(cachePath)/\(fileCheck)"
                    print("Coping from \(resourceExists) to \(copyTo)")
                    do {
                        try fileManager.copyItemAtPath(resourceExists!, toPath: copyTo)
                        print("Copied!")
                    } catch _ {
                        print("NOT COPIED!")
                    }
                } else {
                    //println("Resource not in bundle, must download \(theFile)!")
                    downloadCount += 1
                    self.detailDescriptionLabel.text = "Downloading \(self.downloadCount) sounds."

                    let soundPath = cacheSoundDirectoryName().stringByAppendingPathComponent(fileCheck)
                    let soundURL = "\(downloadURL)\(fileid)"
                    print("Downloading from \(soundURL)")
                    let request = NSURLRequest(URL: NSURL(string: soundURL)!)
                    let config = NSURLSessionConfiguration.defaultSessionConfiguration()
                    let session = NSURLSession(configuration: config)
                        
                    let task : NSURLSessionDataTask = session.dataTaskWithRequest(request, completionHandler: {(soundData, response, error) in
                        if (soundData != nil) {
                            NSFileManager.defaultManager().createFileAtPath(soundPath, contents: soundData, attributes: nil)
                            print("Sound is now Cached! \(soundPath)")
                            self.downloadCount = self.downloadCount - 1
                            self.detailDescriptionLabel.text = "Downloading \(self.downloadCount) sounds."
                        } else {
                            print("SOMETHNIG WRONG WITH soundData 😤")
                        }
                            
                    });
                    task.resume()
                }
            }
        }
    }
    
    func cacheSoundDirectoryName() -> NSString {
        let directory = "Sounds"
        let cacheDirectoryName = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0] as NSString
        let finalDirectoryName = cacheDirectoryName.stringByAppendingPathComponent(directory)
        
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(finalDirectoryName, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
        
        return finalDirectoryName
    }
    
    func loadGame() {
        //http://www.bytearray.org/?p=5517
        //Download JSON, check if file exists, download missing files.
        
        if loaded == false {
            print("Loaded in FALSE...")
            self.detailDescriptionLabel.hidden = false
            self.loadingActivitySpinner.hidden = false
            self.gameDescription.hidden = true
        } else {
            print("Loaded is TRUE")
        }
        
        if let detail: AnyObject = self.detailItem {
            print("Maybe I'm loading?")
            if let gameID = detail.objectForKey("_id") as? String {
                print("Loading gameID \(gameID)")
                let request = NSURLRequest(URL: NSURL(string: "https://mld.jensenius.org/api/dump/" + gameID)!)
                let detailSession = NSURLSession.sharedSession()
                
                detailSession.dataTaskWithRequest(request, completionHandler: {(data, response, error) in
                    print("Finished lodaing?")
                    var jsonResult : AnyObject!
                    do {
                        jsonResult = try NSJSONSerialization.JSONObjectWithData(data!, options: [])
                    } catch {
                        print("Well, shit (delegate!) again, another error")
                    }
                    // we grab the colorsArray element
                    //println(jsonResult.count)
                    dispatch_async(dispatch_get_main_queue(), {
                        if jsonResult.objectForKey("introduction") != nil {
                            self.gameDescription.text = jsonResult.objectForKey("introduction") as? String
                            //print("Set the game description \(self.gameDescription.text)")
                        } else {
                            self.gameDescription.text = "No introduction text has been entered in the settings."
                        }
                        self.gameDescription.textColor = UIColor.whiteColor()
                        self.gameDescription.font = UIFont.systemFontOfSize(18.0)
                    
                        self.currentGame = jsonResult as! NSDictionary
                        self.layers = jsonResult["layer"] as! NSArray
                        self.loaded = true
                    })
                }).resume()
                print("SHOULD REALLY BE LOADING!")
            }
        }
    }
    
    func connection(connection: NSURLConnection!, didReceiveData conData: NSData!) {
        self.bytes?.appendData(conData)
    }
    
    func connection(didReceiveResponse: NSURLConnection!, didReceiveResponse response: NSURLResponse!) {
        self.bytes = NSMutableData()
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection!) {
        // we serialize our bytes back to the original JSON structure
        if connection == loader {
            print("Finished lodaing?")
            let jsonResult: Dictionary = ((try! NSJSONSerialization.JSONObjectWithData(self.bytes!, options: NSJSONReadingOptions.MutableContainers)) as! Dictionary<String, AnyObject>)
            // we grab the colorsArray element
            //println(jsonResult.count)
            dispatch_async(dispatch_get_main_queue(), {
                if jsonResult["introduction"] != nil {
                    self.gameDescription.text = jsonResult["introduction"] as? String
                    print("Set the game description \(self.gameDescription.text)")
                } else {
                    self.gameDescription.text = "No introduction text has been entered in the settings."
                }
                self.gameDescription.textColor = UIColor.whiteColor()
                self.gameDescription.font = UIFont.systemFontOfSize(18.0)
            
                self.currentGame = jsonResult
                self.layers = jsonResult["layer"] as! NSArray
                self.loaded = true
            })
        } else {
            print("Must have finished downloading file")
        }
    }
    
    func stopEverything() {
        print("Going to stop everything!")
        gameLoader.invalidate()
        for layer in layers {
            //var layerTitle = layer["title"] as! NSString
            //println("Checking layer: \(layerTitle)")
            
            let zones = layer["zone"] as! NSArray
            for zone in zones {
                let id = zone["_id"] as! NSString
                if eventPlayers.objectForKey(id) != nil {
                    (eventPlayers.objectForKey(id) as! AVAudioPlayer).stop()
                    eventPlayers.removeObjectForKey(id)
                }
                if identityPlayers.objectForKey(id) != nil {
                    (identityPlayers.objectForKey(id) as! AVAudioPlayer).stop()
                    identityPlayers.removeObjectForKey(id)
                }
            }
        }
        locationManager.stopUpdatingLocation()
    }
    
    func restartEverything() {
        print("Going to restart everything!")
        for layer in layers {
            //var layerTitle = layer["title"] as! NSString
            //println("Checking layer: \(layerTitle)")
            
            let zones = layer["zone"] as! NSArray
            for zone in zones {
                let id = zone["_id"] as! NSString
                (eventPlayers.objectForKey(id) as! AVAudioPlayer).play()
                (identityPlayers.objectForKey(id) as! AVAudioPlayer).play()
            }
        }
        locationManager.startUpdatingLocation()
    }

}

