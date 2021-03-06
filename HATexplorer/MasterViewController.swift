//
//  MasterViewController.swift
//  HATexplorer
//
//  Created by David Jensenius on 2015-07-22.
//  Copyright (c) 2015 David Jensenius. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil
    var objects = [AnyObject]()
    


    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //self.navigationItem.leftBarButtonItem = self.editButtonItem()

        self.title = "Games"

        //let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
        //self.navigationItem.rightBarButtonItem = addButton
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            //self.detailViewController = controllers[controllers.count-1].topViewController as? DetailViewController
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        get_data_from_url("https://mld.jensenius.org/api/map")

        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let object = objects[indexPath.row] as! NSDictionary
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = object
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }
    

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) 

        let object = objects[indexPath.row] as! NSDictionary
        cell.textLabel!.text = object.valueForKey("title") as? String
        if (object.valueForKey("introduction") != nil) {
            cell.detailTextLabel!.text = object.valueForKey("introduction") as? String
        } else {
            cell.detailTextLabel!.text = ""
        }
        return cell
    }
    
    func get_data_from_url(url:String) {
        print("Getting data!", terminator: "")
        //let httpMethod = "GET"
        //let timeout = 15
        let url = NSURL(string: url)
        let urlRequest = NSMutableURLRequest(URL: url!,
            cachePolicy: .ReloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 15.0)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(urlRequest) { (data, response, error) in
            if data!.length > 0 && error == nil{
                let json = NSString(data: data!, encoding: NSUTF8StringEncoding)
                self.extract_json(json!)
            }else if data!.length == 0 && error == nil{
                print("Nothing was downloaded")
            } else if error != nil{
                print("Error happened = \(error)")
            }
        }
        task.resume()
    }
    
    func extract_json(data:NSString) {
        var parseError: NSError?
        let jsonData:NSData = data.dataUsingEncoding(NSUTF8StringEncoding)!
        let json: AnyObject?
        do {
            json = try NSJSONSerialization.JSONObjectWithData(jsonData, options: [])
        } catch let error as NSError {
            parseError = error
            json = nil
        }
        if (parseError == nil) {
            if var game_list = json as? NSArray {
                game_list = game_list.reverseObjectEnumerator().allObjects
                for i in 0 ..< game_list.count {
                    if let game_obj = game_list[i] as? NSDictionary {
                        if let game_name = game_obj["title"] as? String {
                            if let game_id = game_obj["_id"] as? String {
                                if let game_introduction = game_obj["introduction"] as? String {
                                    print("Game name \(game_name) game id \(game_id) game introduction \(game_introduction)")
                                    objects.insert(game_obj, atIndex: 0)
                                } else {
                                    objects.insert(game_obj, atIndex: 0)
                                }
                            }
                        }
                    }
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), {
            self.tableView.reloadData()
            return
        })
    }
}

