//
//  ViewController.swift
//  Sprint0
//
//  Created by Alexis Ponce on 6/4/21.
//

import UIKit
import CoreLocation
import HealthKit
import MapKit

class ViewController: UIViewController, CLLocationManagerDelegate{
    struct weather:Decodable{
        let main: temperature?
    }
    struct temperature:Decodable{
        var temp: Double?
    }
    
    
    
    
    let manager = CLLocationManager()// lcoation manager that directly grabs the location of the devicce
    var location: CLLocation?// variable that will store the location grabed
    var checkRepeat:Double?// will be used to check if the location is in an infinite loop(only for protyping the gpx file)
    var distance:Double?// will be adding the distance between annotations
    var loc1:CLLocation?// will store the previous loatation
    var loc2:CLLocation?// will store the current locaiton
    
    
    var justStarted:Int?// will be used because of th infinite loop of gpx file and to know             if the location service just started in order to calculate distance
    
    //create a variable to access the HKHealthStore
    var healthStore:HKHealthStore!
    
    var urlString = "http://api.openweathermap.org/data/2.5/weather?"

    @IBOutlet weak var temperature: UILabel!
    
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var map: MKMapView!// item connected the the mapView item in sotryBoard
    @IBOutlet weak var long: UILabel!// label to display the current locaiton
    @IBOutlet weak var lat: UILabel!// label to display the current location
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        self.justStarted = 1;
        /* sets the location parameters, am using best accuarcy, but it may drain battery in real world scenarios. Only grabbinng locations when the user is in app*/
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations[0]// stores the location in the global variable
        
        let coordSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let coordRegion = MKCoordinateRegion(center: location!.coordinate, span: coordSpan)
        self.map.setRegion(coordRegion, animated: true)
        /* sets the map area, using a close span because of gpx file, region surrounded by the location*/
        
        self.getWeather(long: (location?.coordinate.longitude)!, lat: (location?.coordinate.latitude)!)// call the weather function
        
        
        let annot = MKPointAnnotation()
        annot.coordinate = location!.coordinate
        annot.title = location?.description
        self.map.addAnnotation(annot)
        /* adds an annotation witht the location and description of location*/
        
        /*
        print("You are at a latititude of \(String(describing: location?.coordinate.latitude)) and a logntitude of \(String(describing: location?.coordinate.longitude))")
        let latitude = (location?.coordinate.latitude)!
        let longtitude = (location?.coordinate.longitude)!
        self.lat.text = "\(latitude)"//sets the latitude label to the locations latitude
        self.long.text = "\(longtitude)"// sets the longtitude to the location longtitude
        for (index,val) in locations.enumerated(){
            print("These are the locations with a lat of: \(val.coordinate.latitude)\n and a long of: \(val.coordinate.longitude)\n")//loops through the locations
        }*/
        /* prints the location in the console and in the label*/
        
        if(self.justStarted == 1){// first location
            loc1 = CLLocation(latitude: (location?.coordinate.latitude)!, longitude: (location?.coordinate.longitude)!)
            distance = 0
            print(" first distance \(distance!)\n")
            self.justStarted! += 1
            self.distanceLabel.text = String(describing: distance!)
        }else{
            loc2 = CLLocation(latitude: (location?.coordinate.latitude)!, longitude: (location?.coordinate.longitude)!)
            distance! += (loc2?.distance(from: loc1!))!
            print("Distance after the first \(distance!)")
            loc1 = loc2
            self.justStarted! += 1
            self.distanceLabel.text = String(describing: distance!)
        }
        grabHeartRate()
        
    }
    
    func grabHeartRate(){
        //create and saving a sampple
        let typeToShare:Set = [HKObjectType.workoutType()]
        let typeToRead = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!])
        if(HKHealthStore.isHealthDataAvailable()){
            self.healthStore = HKHealthStore()
            self.healthStore.requestAuthorization(toShare: typeToShare, read: typeToRead){(success, error) in
            if(!success){
                print("something went wrong when trying to access healthKit data\n")
                print("Here is the error \(String(describing: error?.localizedDescription))")
            }else{
               
            }
        }
        }else{
            print("healkit is not available on this device")
        }
        
    }
    
    
    func getWeather(long:Double, lat:Double){// will be used to gather the temp of the users location
        self.urlString += "lat=\(lat)&lon=\(long)&appid=416f2decd9f93e02858f215756151bbd&units=imperial"
        let realURL = URL(string: self.urlString)!
        let urlSession = URLSession.shared
        
        let jsonQuery = urlSession.dataTask(with: realURL){(data,response, error) in
            if let error = error{
                print("There was an error grabbing accessing the API error code:  \(error.localizedDescription)")
            }
            if let data = data{
            let decoder = JSONDecoder()
                let jsonDecoder = try? decoder.decode(weather.self, from: data)
                if let temped = jsonDecoder?.main{
                    print(temped.temp!)
                    DispatchQueue.main.async {
                        self.temperature.text = String(describing: temped.temp!)
                    }
                }
            }else{
                
            }
            
        }
        jsonQuery.resume()
    }
    
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)// if there is an error grabbing the locations this will print it
    }
}

