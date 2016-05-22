//
//  CityAnnotation.swift
//  MapWeather
//
//  Created by Raggios on 5/21/16.
//  Copyright © 2016 Raggios. All rights reserved.
//

import UIKit
import MapKit

class CityAnnotation: NSObject, MKAnnotation{
    
    private var city: String?
    private var temperature: String?
    private let operationQueue = NSOperationQueue()
    
    let coordinate: CLLocationCoordinate2D
    var forecastURLString: String?
    var forecastView:UIView?
    
    var title: String? {
        return city
    }
    
    var subtitle: String? {
        return temperature
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
        resetData()
    }
    
    // could use error checking here in case json is malformed
    func loadDataForView(view:MKAnnotationView){
        
        let blockOperation = NSBlockOperation()
        
        blockOperation.addExecutionBlock {
            
            if let jsonDict:NSDictionary = self.getJSON(self.coordinate){
                
                // no need to parse json and get image if the block was cancelled
                if blockOperation.cancelled { return }
                
                let observation = jsonDict["current_observation"] as! NSDictionary
                let location = observation["display_location"] as! NSDictionary
                
                self.city = (location["full"] as? String)!
                
                // force https since calls to http will fail!  This is due to ATS.  Could also add exception to plist
                if let urlString = observation["icon_url"] as? String{
                    if let imageURL = NSURL(string: urlString.stringByReplacingOccurrencesOfString("http:", withString: "https:")){
                        if let imageData = NSData(contentsOfURL: imageURL){
                            let forecastImage = UIImage(data: imageData)
                            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 45, height: 45))
                            imageView.contentMode = UIViewContentMode.ScaleAspectFill;
                            imageView.image = forecastImage
                            self.forecastView = imageView
                        }
                    }
                }
                
                if let fedURLString = observation["forecast_url"] as? String{
                    self.forecastURLString = fedURLString.stringByReplacingOccurrencesOfString("http:", withString: "https:")
                }
                
                self.temperature = observation["temperature_string"] as? String
            }
            
            
            // Now that the data was loaded above, update the UI on the main thread
            // if the block was not cancelled
            if !blockOperation.cancelled {
                
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    
                    view.leftCalloutAccessoryView = self.forecastView
                    
                    self.willChangeValueForKey("subtitle")
                    self.didChangeValueForKey("subtitle")
                    
                    self.willChangeValueForKey("title")
                    self.didChangeValueForKey("title")}
                
            }
        }
        
        operationQueue.addOperation(blockOperation)
        
    }
    
    // this is called when the annotation is hidden, so that the placeholder values are restored
    // for those fields that can change over time (temperture and icon)
    // The city name and URL for forecast do not change
    // new data will be retrieved when the annotation is selected again.
    // This could be optomized to not clear the data within a certain time frame.
    func resetData(){
        operationQueue.cancelAllOperations()
        
        temperature = nil
        
        // Need a placeholder or the pin will suppress callouts!
        city = "Loading City & Weather"
        
        // show an activity indicator as the left accessory.  It will be replaced later when the weather data is loaded
        let activity = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        activity.startAnimating()
        self.forecastView = activity

    }
    
    private func getJSON(coordinate: CLLocationCoordinate2D) -> NSDictionary?{
        
        var result:NSDictionary?
        
        let coordinateURLString: String = "https://api.wunderground.com/api/5932fa7b05de42a2/conditions/forecast/alert/q/\(coordinate.latitude),\(coordinate.longitude).json"
        let url: NSURL? = NSURL( string: coordinateURLString)
        
        if let jsonData:NSData = NSData(contentsOfURL: url!){
            do {
                result = try NSJSONSerialization.JSONObjectWithData(jsonData, options: NSJSONReadingOptions.MutableContainers) as? NSDictionary
            } catch let error as NSError {
                print("Failed to load: \(error.localizedDescription)")
            }
        }
        
        return result
    }
    
}

// samples used http, but that gave a runtime warning.  Looks like https works
// Get the city name from lat,long
// https://api.wunderground.com/api/5932fa7b05de42a2/geolookup/q/40.75921100,-73.98463800.json

// get the weather from city name
// https://api.wunderground.com/api/5932fa7b05de42a2/conditions/q/NY/New%20York.json that is retrieved above from lat/long

// forecast for a given lat/long -> this one UNDOCUMENTED call alone gets the city name and the weather
// https://api.wunderground.com/api/5932fa7b05de42a2/conditions/forecast/alert/q/40.75921100,-73.98463800.json


