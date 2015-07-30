//
//  DetailViewController.swift
//  HATexplorer
//
//  Created by David Jensenius on 2015-07-22.
//  Copyright (c) 2015 David Jensenius. All rights reserved.
//

import UIKit
import MapKit

class DetailViewController: UIViewController, CLLocationManagerDelegate, AVAudioPlayerDelegate {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    
    @IBOutlet weak var loadingActivitySpinner: UIActivityIndicatorView!
    @IBOutlet weak var gameDescription: UITextView!
    
    let downloadURL = "https://nyu.hatengine.com/download/"
    
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
    
    var loader = NSURLConnection()
    var downloader = NSURLConnection()
    var downloadCount = 0
    
    var currentEvent = NSString()
    
    dynamic var identityPlayers = NSMutableDictionary()
    dynamic var identityPlayerItems = NSMutableDictionary()
    dynamic var eventPlayers = NSMutableDictionary()
    dynamic var eventPlayerItems = NSMutableDictionary()
    var eventDebug = NSMutableDictionary()
    var identityDebug = NSMutableDictionary()
    
    let userDefaults = NSUserDefaults.standardUserDefaults()
    

    var detailItem: AnyObject? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }

    func configureView() {
        // Update the user interface for the detail item.
        if let detail: AnyObject = self.detailItem {
            if let label = self.detailDescriptionLabel {
                label.text = "Loading Game"
                self.title = detail.objectForKey("title") as? String
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
        // Background sound
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        
        //loadGame()
        
        //Let's reload game data every 10 seconds
        NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "loadGame", userInfo: nil, repeats: true)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "stopEverything", name: "stopEverything", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "restartEverything", name: "restartEverything", object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        //Stop everything
        stopEverything()
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        currentLat = manager.location.coordinate.latitude - offsetLat
        currentLon = manager.location.coordinate.longitude - offsetLng
        currentLocation = CLLocation(latitude: currentLat, longitude: currentLon)
        
        println("I have a location and I am loading more stuff")
        if (loaded == true) {
            checkStates()
        }
    }
    
    func checkStates() {
        var leastDistance = 1000000000000.1
        if (firstLoop == true) {
            println("First loop, checking to see if we are in range")
            for layer in layers {
                var layerTitle = layer["title"] as! NSString
                //println("Checking layer: \(layerTitle)")
                
                var zones = layer["zone"] as! NSArray
                for zone in zones {
                    var zoneTitle = zone["title"] as! NSString
                    
                    if (inGameArea == false) {
                        var polygon = zone["polygon"] as! NSArray
                        println("Checking zone \(zoneTitle)")
                        if (insidePolygon(polygon)) {
                            inGameArea = true
                            inPolygon = true
                        }
                        
                        var distance = distanceFromPolygon(polygon)
                        if (distance < leastDistance) {
                            leastDistance = distance
                        }
                    }
                    
                    var identity = zone["identity"] as! NSDictionary
                    checkFiles(identity["file"] as! NSArray)
                    
                    var event = zone["event"] as! NSDictionary
                    checkFiles(event["file"] as! NSArray)
                    
                    //println("Identity is \(identity) ")
                }
            }
            //For now, if we are a kilometer away from the nearest sound, we will bail and set offsets
            if currentGame["longitude"] != nil {
                if (leastDistance > 1000) {
                    offsetLng = currentLon - (currentGame["longitude"] as! Double)
                    offsetLat = currentLat - (currentGame["latitude"] as! Double)
                    println("We are offsetting by \(offsetLat), \(offsetLng)")
                } else {
                    offsetLat = 0
                    offsetLng = 0
                    println("No offsetting needed")
                }
            }
            
            firstLoop = false
        } else if downloadCount == 0 {
            println("Regular loop")
            //Let's get sounds playing!
            self.detailDescriptionLabel.hidden = true
            self.loadingActivitySpinner.hidden = true
            self.gameDescription.hidden = false
            
            for layer in layers {
                var layerTitle = layer["title"] as! NSString
                //println("Checking layer: \(layerTitle)")
                
                var zones = layer["zone"] as! NSArray
                for zone in zones {
                    var zoneTitle = zone["title"] as! NSString
                    var id = zone["_id"] as! NSString
                    var polygon = zone["polygon"] as! NSArray
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
                    
                    var distance = distanceFromPolygon(polygon)
                    if (distance < leastDistance) {
                        leastDistance = distance
                    }
                    
                    var identity = zone["identity"] as! NSDictionary
                    var event = zone["event"] as! NSDictionary
                    var zt = zone["title"] as! NSString
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
        if (identityPlayers.objectForKey(zoneId) == nil && eventPlayers.objectForKey(zoneId) == nil) {
            //Create item!
            println("Having to create?")
            //loop through both identity and event files, grab the last one and set it to play: FIX LATER
            
            let cachePath = cacheSoundDirectoryName()
            var hasIdentitySound = false
            var files:NSArray = identity["file"] as! NSArray
            var identityURL = NSURL()
            for file in files {
                let currentFile = file as! NSDictionary
                let fileid = currentFile["_id"] as! NSString
                let ext = currentFile["title"]!.pathExtension
                let fileCheck = "\(fileid).\(ext)"
                identityURL = NSURL(fileURLWithPath: cachePath.stringByAppendingPathComponent(fileCheck))!
                hasIdentitySound = true
            }
            
            
            if hasIdentitySound == true {
                identityPlayers.setObject(AVAudioPlayer(contentsOfURL: identityURL, error: nil), forKey: zoneId)
                (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).numberOfLoops = -1
                (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
                (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).play()
            }
            
            var eventFiles:NSArray = event["file"] as! NSArray
            //println("Event files \(eventFiles)")
            var eventURL = NSURL()
            var hasEventSound = false
            for file in eventFiles {
                let currentFile = file as! NSDictionary
                let fileid = currentFile["_id"] as! NSString
                let ext = currentFile["title"]!.pathExtension
                let fileCheck = "\(fileid).\(ext)"
                eventURL = NSURL(fileURLWithPath: cachePath.stringByAppendingPathComponent(fileCheck))!
                hasEventSound = true
            }
            
            if hasEventSound == true {
                eventPlayers.setObject(AVAudioPlayer(contentsOfURL: eventURL, error: nil), forKey: zoneId)
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).numberOfLoops = -1
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).play()
            }
        }
        
        if polygon != "" {
            if eventPlayers.objectForKey(polygon) != nil {
                (eventPlayers.objectForKey(polygon) as! AVAudioPlayer).volume = 1.0
            }
            if (zoneId != polygon) {
                if eventPlayers.objectForKey(zoneId) != nil {
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
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
                println("Event not nil")
            }
            
            var distanceFrom = Float()
            userDefaults.synchronize()
            var formula = NSString()
            if let useLog: AnyObject = userDefaults.objectForKey("logIdentity") {
                println(useLog);
                if (useLog as! Bool == true) {
                    //Logorithmic growth
                    println("Logorithmic growth!")
                    distanceFrom = 1 + log(Float(distance / 1000))
                    formula = "1 + log(Float(\(distance) / 1000))"
                    
                } else {
                    //Normal growth
                    println("Normal growth!")
                    distanceFrom = 1 + Float(distance / 1000)
                    formula = "1 + Float(\(distance) / 1000)"
                }
            } else {
                //Normal growth
                println("Normal growth!")
                distanceFrom = 1 + Float(distance / 1000)
                formula = "1 + Float(\(distance) / 1000)"
            }
            
            if (distanceFrom < 0) {
                distanceFrom = 0
            }
            
            println("Actual distance: \(distance)")
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
            var debugText = "\(zoneTitle)\nDistance - \(distance)\nAdjusted Value - \(distanceFrom)\nVolume - \(volume)\n\(formula)"
            println(debugText)
            identityDebug.setObject(debugText, forKey: zoneId)
            
        }
    }
    
    func playerItemDidReachEnd(notification: NSNotification) {
        println("Looping?? \(notification.object)")
        var p:AVPlayerItem  = notification.object as! AVPlayerItem
        p .seekToTime(kCMTimeZero)
    }
    
    func insidePolygon(polygons:NSArray) -> Bool {
        //http://web.archive.org/web/20080812141848/http://local.wasp.uwa.edu.au/~pbourke/geometry/insidepoly/
        //http://stackoverflow.com/questions/25835985/determine-whether-a-cllocationcoordinate2d-is-within-a-defined-region-bounds
        //println("Checking polygon \(polygons)")
        
        var  polyCoords:Array<CLLocationCoordinate2D> = []
        
        for(var i = 0; i < polygons.count; i++) {
            var polygon = polygons[i] as! NSDictionary
            //let curLat = polygon["latitude"] as! CLLocationDegrees
            polyCoords.append(CLLocationCoordinate2DMake(polygon["latitude"] as! CLLocationDegrees, polygon["longitude"] as! CLLocationDegrees))
        }
        
        var mpr:CGMutablePathRef = CGPathCreateMutable()
        
        for (var i = 0; i < polyCoords.count; i++) {
            var c:CLLocationCoordinate2D = polyCoords[i]
            
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
            let location = coords as! NSDictionary
            let pointLocation = CLLocation(latitude: coords["latitude"] as! CLLocationDegrees, longitude: coords["longitude"] as! CLLocationDegrees)
            var distanceFrom = pointLocation.distanceFromLocation(currentLocation)
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
            let ext = theFile["title"]!.pathExtension
            let fileid = theFile["_id"] as! NSString
            let filename = theFile["title"] as! NSString
            
            let fileCheck = "\(fileid).\(ext)"
            if NSFileManager.defaultManager().fileExistsAtPath(cachePath.stringByAppendingPathComponent(fileCheck)) {
                println("File exists in cache")
            } else {
                let resourceExists = NSBundle.mainBundle().pathForResource(fileid as String, ofType: ext)
                if ((resourceExists) != nil) {
                    println("Resource in bundle")
                    let fileManager = NSFileManager.defaultManager()
                    let copyTo = "\(cachePath)/\(fileCheck)"
                    println("Coping from \(resourceExists) to \(copyTo)")
                    if fileManager.copyItemAtPath(resourceExists!, toPath: copyTo, error: nil) {
                        println("Copied!")
                    } else {
                        println("NOT COPIED!")
                    }
                } else {
                    //println("Resource not in bundle, must download \(theFile)!")
                    downloadCount++
                    self.detailDescriptionLabel.text = "Downloading \(self.downloadCount) sounds."

                    let soundPath = cacheSoundDirectoryName().stringByAppendingPathComponent(fileCheck)
                    let soundURL = "\(downloadURL)\(fileid)"
                    println("Downloading from \(soundURL)")
                    var request = NSURLRequest(URL: NSURL(string: soundURL)!)
                    let config = NSURLSessionConfiguration.defaultSessionConfiguration()
                    let session = NSURLSession(configuration: config)
                        
                    let task : NSURLSessionDataTask = session.dataTaskWithRequest(request, completionHandler: {(soundData, response, error) in
                        if (soundData != nil) {
                            NSFileManager.defaultManager().createFileAtPath(soundPath, contents: soundData, attributes: nil)
                            println("Sound is now Cached! \(soundPath)")
                            self.downloadCount--
                            self.detailDescriptionLabel.text = "Downloading \(self.downloadCount) sounds."
                        } else {
                            println("SOMETHNIG WRONG WITH soundData 😤")
                        }
                            
                    });
                    task.resume()
                }
            }
        }
    }
    
    func cacheSoundDirectoryName() -> NSString {
        let directory = "Sounds"
        let cacheDirectoryName = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0] as! NSString
        let finalDirectoryName = cacheDirectoryName.stringByAppendingPathComponent(directory)
        
        /* Swift 2 version
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(finalDirectoryName, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
        */
        NSFileManager.defaultManager().createDirectoryAtPath(finalDirectoryName, withIntermediateDirectories: true, attributes: nil, error: nil)
        return finalDirectoryName
    }
    
    func loadGame() {
        //http://www.bytearray.org/?p=5517
        //Download JSON, check if file exists, download missing files.
        
        if loaded == false {
            self.detailDescriptionLabel.hidden = false
            self.loadingActivitySpinner.hidden = false
            self.gameDescription.hidden = true
        }
        
        if let detail: AnyObject = self.detailItem {
            if let gameID = detail.objectForKey("_id") as? String {
                let request = NSURLRequest(URL: NSURL(string: "http://nyu.hatengine.com/api/dump/" + gameID)!)
                loader = NSURLConnection(request: request, delegate: self, startImmediately: true)!
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
            let jsonResult: Dictionary = (NSJSONSerialization.JSONObjectWithData(self.bytes!, options: NSJSONReadingOptions.MutableContainers, error: nil) as! Dictionary<String, AnyObject>)
            // we grab the colorsArray element
            //println(jsonResult.count)
            if jsonResult["introduction"] != nil {
                gameDescription.text = jsonResult["introduction"] as? String
            } else {
                gameDescription.text = "No introduction text has been entered in the settings."
            }
            gameDescription.textColor = UIColor.whiteColor()
            
            currentGame = jsonResult
            layers = jsonResult["layer"] as! NSArray
            loaded = true
        } else {
            println("Must have finished downloading file")
        }
    }
    
    func stopEverything() {
        println("Going to stop everything!")
        for layer in layers {
            var layerTitle = layer["title"] as! NSString
            //println("Checking layer: \(layerTitle)")
            
            var zones = layer["zone"] as! NSArray
            for zone in zones {
                var id = zone["_id"] as! NSString
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
        println("Going to restart everything!")
        for layer in layers {
            var layerTitle = layer["title"] as! NSString
            //println("Checking layer: \(layerTitle)")
            
            var zones = layer["zone"] as! NSArray
            for zone in zones {
                var id = zone["_id"] as! NSString
                (eventPlayers.objectForKey(id) as! AVAudioPlayer).play()
                (identityPlayers.objectForKey(id) as! AVAudioPlayer).play()
            }
        }
        locationManager.startUpdatingLocation()
    }

}

