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
    
    var loader = NSURLConnection()
    var downloader = NSURLConnection()
    let downloadCount:NSInteger = 0
    
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
                label.text = detail.description
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
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
        
        
        loadGame()
        
        //Let's reload game data every 10 seconds
        NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "loadGame", userInfo: nil, repeats: true)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "stopEverything", name: "stopEverything", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "restartEverything", name: "restartEverything", object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        //Stop everything
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        currentLat = manager.location.coordinate.latitude - offsetLat
        currentLon = manager.location.coordinate.longitude - offsetLng
        currentLocation = CLLocation(latitude: currentLat, longitude: currentLon)
        
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
            if (leastDistance > 1000) {
                offsetLng = currentLon - (currentGame["longitude"] as! Double)
                offsetLat = currentLat - (currentGame["latitude"] as! Double)
            } else {
                offsetLat = 0
                offsetLng = 0
            }
            
            firstLoop = false
        } else if downloadCount == 0 {
            //println("Regular loop")
            //Let's get sounds playing!
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
        if (identityPlayers.objectForKey(zoneId) == nil) {
            //Create item!
            
            //loop through both identity and event files, grab the last one and set it to play: FIX LATER
            
            let cachePath = cacheDirectory()
            
            var files:NSArray = identity["file"] as! NSArray
            var identityURL = NSURL()
            for file in files {
                let currentFile = file as! NSDictionary
                let fileid = currentFile["_id"] as! NSString
                let ext = currentFile["title"]!.pathExtension
                let fileCheck = "\(fileid).\(ext)"
                identityURL = NSURL(fileURLWithPath: cachePath.stringByAppendingPathComponent(fileCheck))!
            }
            
            identityPlayers.setObject(AVAudioPlayer(contentsOfURL: identityURL, error: nil), forKey: zoneId)
            (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).numberOfLoops = -1
            (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
            (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).play()
            
            var eventFiles:NSArray = event["file"] as! NSArray
            println("Event files \(eventFiles)")
            var eventURL = NSURL()
            for file in eventFiles {
                let currentFile = file as! NSDictionary
                let fileid = currentFile["_id"] as! NSString
                let ext = currentFile["title"]!.pathExtension
                let fileCheck = "\(fileid).\(ext)"
                eventURL = NSURL(fileURLWithPath: cachePath.stringByAppendingPathComponent(fileCheck))!
            }
            
            eventPlayers.setObject(AVAudioPlayer(contentsOfURL: eventURL, error: nil), forKey: zoneId)
            (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).numberOfLoops = -1
            (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
            (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).play()
        }
        
        if polygon != "" {
            (eventPlayers.objectForKey(polygon) as! AVAudioPlayer).volume = 1.0
            if (zoneId != polygon) {
                (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
            }
            (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
            
        } else {
            //Set volume!
            //Make sure all events are muted then set other volumes
            (eventPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = 0.0
            
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
            (identityPlayers.objectForKey(zoneId) as! AVAudioPlayer).volume = volume
            var debugText = "\(zoneTitle)\nDistance - \(distance)\nAdjusted Value - \(distanceFrom)\nVolume - \(volume)\n\(formula)"
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
        let cachePath = cacheDirectory()
        
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
                    println("Resource not in bundle, must download!")
                    if downloadCount == 0 {
                        let soundURL = "\(downloadURL)\(fileCheck)"
                        let soundData = NSData(contentsOfURL: soundURL!)
                        if (soundData != nil) {
                            NSFileManager.defaultManager().createFileAtPath(soundPath, contents: soundData, attributes: nil)
                            print("Sound is now Cached! \(soundPath)")
                        }
                    }
                }
            }
        }
    }
    
    func loadGame() {
        //http://www.bytearray.org/?p=5517
        //Download JSON, check if file exists, download missing files.
        
        println("Loading game...")
        
        let request = NSURLRequest(URL: NSURL(string: "http://mld.jensenius.org/api/dump/553c1a437d6e7793143af73f")!)
        loader = NSURLConnection(request: request, delegate: self, startImmediately: true)!
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
            println(jsonResult.count)
            
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
                (eventPlayers.objectForKey(id) as! AVAudioPlayer).stop()
                (identityPlayers.objectForKey(id) as! AVAudioPlayer).stop()
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
    
    func cacheDirectory() -> NSString {
        var directory = NSString()
        let nsDocumentDirectory = NSSearchPathDirectory.DocumentDirectory
        let nsUserDomainMask = NSSearchPathDomainMask.UserDomainMask
        var dirPath = NSString()
        if let paths = NSSearchPathForDirectoriesInDomains(nsDocumentDirectory, nsUserDomainMask, true) {
            if paths.count > 0 {
                dirPath = paths[0] as! NSString
                
            }
        }
        return dirPath
    }

}
