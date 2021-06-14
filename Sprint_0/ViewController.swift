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
import WatchConnectivity
import CoreMotion

class ViewController: UIViewController, CLLocationManagerDelegate, WCSessionDelegate{
    
    // structs that will be used to gather the user tempereature based on the coordinates
    struct weather:Decodable{
        let main: temperature?
    }
    struct temperature:Decodable{
        var temp: Double?
    }
    
    var timer: Timer?
    @IBOutlet weak var timerMSG: UILabel!
    var mili = 0.00
    var sec = 0
    var min = 0
    var hour = 0
    
    // creat a watch connection variable
    var session:WCSession?
    var isActive:Bool = false // used to check if it actualy connected to an app
    
    //create a variable to access the HKHealthStore and associated variables
    var healthStore:HKHealthStore!
    var myWorkout: HKWorkout?
    var startDate = Date()
    var hearRateAVG = [Double]()
    var totalCalories:Double?
    
    //for the live workout recording from the iphone
    var liveCongifuration = HKWorkoutConfiguration()
    var inProgress = false
    
    //used to grab the user change in altitude
    var altitude = CMAltimeter()
    var altitudeCounter = 0
    @IBOutlet weak var altitudeMSG: UILabel!
    var cmManager:CMMotionManager?
    var pedometer:CMPedometer?
    @IBOutlet weak var pedometerMSG: UILabel!
    @IBOutlet weak var cadenceMSG: UILabel!
    @IBOutlet weak var paceMSG: UILabel!
    @IBOutlet weak var distancePedometerMSG: UILabel!
    // location variables, manager, loc1/loc2 = calcs for distance, workoutLocation for routeBuilder
    let manager = CLLocationManager()
    var location: CLLocation?
    var loc1:CLLocation?
    var loc2:CLLocation?
    var workoutLocations = [CLLocation]()
    
    @IBOutlet weak var trueHeadingMSG: UILabel!
    @IBOutlet weak var magHeadingMSG: UILabel!
    
    
    var checkRepeat:Double?// will be used to check if the location is in an infinite loop(only for protyping the gpx file)
    var distance:Double?// will be adding the distance between annotations
    
    
    //used to check if the there is a current workout in progress
    var workoutInProgress: Int = 0
    
    var justStarted:Int?// will be used because of th infinite loop of gpx file and to know             if the location service just started in order to calculate distance
    
    // start of the API used for temperature, is finished in getWeather func
    var urlString = "http://api.openweathermap.org/data/2.5/weather?"

    
    // storyboards components for health
    @IBOutlet weak var heartRate: UILabel!
    @IBOutlet weak var workoutSeg: UISegmentedControl!
    @IBOutlet weak var calorieMSG: UILabel!
    
    @IBOutlet weak var temperature: UILabel!
    
    // storyBoard components for distance
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var map: MKMapView!// item connected the the mapView item in sotryBoard
    @IBOutlet weak var long: UILabel!// label to display the current locaiton
    @IBOutlet weak var lat: UILabel!// label to display the current location
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // sets up the parameters to grab the uesrs location
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable(){
            manager.startUpdatingHeading()
        }else{
            magHeadingMSG.text = "There is no compass on this device"
            trueHeadingMSG.text = "There is no compass on this device"
        }
        self.justStarted = 1;
        
        //setting up the healthStore and permissoins
        let typeToShare:Set = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        let typeToRead = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!, HKObjectType.workoutType(), HKSeriesType.workoutRoute()])
        if(HKHealthStore.isHealthDataAvailable()){
            self.healthStore = HKHealthStore()
            // will ask the user permission to access data
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
    // setting up the watch connection
        if(WCSession.isSupported()){
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        
        //CoreMotion setup
        self.cmManager = CMMotionManager()
    }
    
    // listens to the users compass direction
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if CLLocationManager.headingAvailable(){
            let magHeading = newHeading.magneticHeading
            let trueHead = newHeading.trueHeading
            DispatchQueue.main.async {
                self.magHeadingMSG.text = "\(magHeading)"
                self.trueHeadingMSG.text = "\(trueHead)"
            }
        }else{
            DispatchQueue.main.async {
                self.magHeadingMSG.text = "There is no compass on this device"
                self.trueHeadingMSG.text = "There is no compass on this device"
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations[0]// stores the location in the global variable
        /* sets the map area, using a close span because of gpx file, region surrounded by the location*/
        let coordSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)//closer span since user is mobile
        let coordRegion = MKCoordinateRegion(center: location!.coordinate, span: coordSpan)
        self.map.setRegion(coordRegion, animated: true)
        
        // call the weather function
        self.getWeather(long: (location?.coordinate.longitude)!, lat: (location?.coordinate.latitude)!)
        // used to track where the uer is, represents current route
        let annot = MKPointAnnotation()
        annot.coordinate = location!.coordinate
        annot.title = location?.description
        self.map.addAnnotation(annot)
        calculateElevation(alt: location!.altitude)
        //print("You are at a latititude of \(String(describing: location?.coordinate.latitude)) and a logntitude of \(String(describing: location?.coordinate.longitude))")
        let latitude = (location?.coordinate.latitude)!
        let longtitude = (location?.coordinate.longitude)!
        self.lat.text = "\(latitude)"//sets the latitude label to the locations latitude
        self.long.text = "\(longtitude)"// sets the longtitude to the location longtitude
    
        // calculates the distance of the user, starts with loc1 with distance =0
            //after the first, loc2 is current locaiton and loc1 is the past location
        if(self.justStarted == 1){// first location
            loc1 = CLLocation(latitude: (location?.coordinate.latitude)!, longitude: (location?.coordinate.longitude)!)
            distance = 0
            print(" first distance \(distance!)\n")
            self.justStarted! += 1
            DispatchQueue.main.async {
                self.distanceLabel.text = "\(String(describing: self.distance!)) m"
            }
        }else{
            loc2 = CLLocation(latitude: (location?.coordinate.latitude)!, longitude: (location?.coordinate.longitude)!)
            distance! += (loc2?.distance(from: loc1!))!
            loc1 = loc2
            self.justStarted! += 1
            let showDist = round(distance! * 10)/10
            DispatchQueue.main.async {
                self.distanceLabel.text = "\(String(describing: showDist)) m"
            }
        }
        
        //constantly stores the new locaiton to a global array, to creat route
        if(self.workoutSeg.selectedSegmentIndex == 1){
            workoutLocations.append(location!)
        }
       
        
    }
    
    
    // function that takes care of starting/ending the workouts
    @IBAction func creatingWorkouts(_ sender: Any) {
        if(HKHealthStore.isHealthDataAvailable()){
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: self.healthStore, device: nil)
            switch self.workoutSeg.selectedSegmentIndex{
            case 0:
                // workout has not started
                break;
            case 1:
                //user wants to start the workout
                self.startDate = Date()
                grabHeartRate()
                startTimer()
                setupMotion()
                break;
            default:
                stopTimer()
                var tempHeartAVG = 0.0
                let finishDate = Date()
                let finalWorkout = HKWorkout(activityType: .running, start: self.startDate, end: finishDate)// workout that is saved to Health app
                let meta:[String: Any] = [HKMetadataKeyWeatherTemperature: HKQuantity(unit: HKUnit(from: "degF"), doubleValue: Double(self.temperature.text!)!)]
                
                //using semaphores because the routBuilder API is async
                let sem = DispatchSemaphore(value: 0)
                
                //inserts the route data using the global loations array
                routeBuilder.insertRouteData(self.workoutLocations){ (success, error) in
                    if(error != nil){
                        print("there was an error when inserting the route data, with an error code of \(error!.localizedDescription)")
                    }
                    if(success){
                        print("Succesfully added the locations to the route builder")
                    }
                    sem.signal()
                }
                sem.wait()
                
                //saves the workout
                self.healthStore.save(finalWorkout){ (finish, error) in
                    if(error != nil){
                        print("There was someting wrong when saving the workout to the healStore with error: \(String(describing: error?.localizedDescription))")
                    }
                    sem.signal()
                }
                sem.wait()
                
                // adds the route to the workout
                routeBuilder.finishRoute(with: finalWorkout, metadata: meta){(route, error) in
                        if(error != nil){
                            print("there was an error when finishing the route with error: \(String(describing: error?.localizedDescription))")
                        }
                        sem.signal()
                }
                sem.wait()
                
                self.healthStore.save(finalWorkout){ (finish, error) in
                    if(error != nil){
                        print("There was someting wrong when saving the workout to the healStore with error: \(String(describing: error?.localizedDescription))")
                    }
                    guard let valid = self.session else{
                        print("Something is wrong with the session, after saving the workout")
                        return
                    }
                    if valid.isReachable{
                        // calculate the average heart rate from the recorded data
                        for (_,val) in self.hearRateAVG.enumerated(){
                                tempHeartAVG += val
                        }
                        //data sample used to add heartRate data
                        var myDataSmple = [HKSample]()
                        // adds the average heart rate to the sample
                        tempHeartAVG = tempHeartAVG/Double((self.hearRateAVG.count))
                        let heartType = HKSampleType.quantityType(forIdentifier: .heartRate)
                        let actualHeartRate = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: tempHeartAVG)
                        let heartRateSample = HKQuantitySample(type: heartType!, quantity: actualHeartRate, start: self.startDate, end: finishDate, device: nil, metadata: nil)
                        myDataSmple.append(heartRateSample)
                        if(self.totalCalories != nil){
                            let calorieSample = HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!, quantity: HKQuantity(unit: HKUnit.largeCalorie(), doubleValue: self.totalCalories!), start: self.startDate, end: finishDate)
                            myDataSmple.append(calorieSample)
                        }
                        // adds the sample data to the workout
                        self.healthStore.add(myDataSmple, to: finalWorkout){(success,error) in
                            if(error != nil){
                                print("Something went wrong when adding the heart rate sample to the workout")
                            }
                        }
                    }else{
                        // grab ios data
                        
                    }
                }
                
                
                // calls this again to tell the watch to stop tracking
                grabHeartRate()
                //user is turning off the wokrout
                break;
            }
        }else{
            //HealthStore is not available
        }
    }
    
    
    //sends messages to the watch to tell it to start tracking the workout
    func grabHeartRate(){//will be used to grab heart samples
      guard let validSession = self.session else{
            print("Something is wrong with the session variable")
            return
        }
        if validSession.isReachable{
            if(self.workoutSeg.selectedSegmentIndex == 1){
                let startWorkoutDic:[String:Any] = ["Workout": "Start"]
                validSession.sendMessage(startWorkoutDic, replyHandler: nil, errorHandler: nil)
            }else if(self.workoutSeg.selectedSegmentIndex == 2){
                let startWorkoutDic:[String:Any] = ["Workout1": "Stop"]
                validSession.sendMessage(startWorkoutDic, replyHandler: nil, errorHandler: nil)
            }
        }else{
            print("The watch is not reachable")
        }
    }
    
    
    func getWeather(long:Double, lat:Double){// will be used to gather the temp of the users location
        self.urlString += "lat=\(lat)&lon=\(long)&units=imperial&appid=416f2decd9f93e02858f215756151bbd"
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
    
    
    func calculateElevation(alt:CLLocationDistance){
        //calculating elevation and change
        // might needt to imlement CMAltitudeData
        //CMAltitudeData
        
        var alt1 = 0.0
        var changeOfAltitude:Double
        
        if self.altitudeCounter == 0{
            self.altitudeMSG.text = "\(alt)"
            changeOfAltitude = 0
            alt1 = alt
            self.altitudeCounter += 1
            
        }else{
            self.altitudeMSG.text = "\(alt)"
            changeOfAltitude = alt - alt1
            alt1 = alt
        }
    }
    
    
    func startTimer(){// will start the timer
        self.timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(showTimer), userInfo: nil, repeats: true)
    }
    
    func stopTimer(){
        self.timer?.invalidate()
    }
    
    @objc func showTimer(){// shows the timer to the UI
        self.mili += 0.01
        self.mili = round(self.mili * 100)/100
        if self.mili == 1.00{
            self.mili = 0.00
            self.sec += 1
        
            if self.sec == 60{
                self.sec = 0
                self.min += 1
        
                if self.min == 60{
                        self.min = 0
                        self.hour += 1
                }
            }
        }
        DispatchQueue.main.async {
            var printMili = Int(self.mili*100)
            if(self.hour < 10){
                if(self.min < 10){
                    if(self.sec < 10){
                        self.timerMSG.text = "0\(self.hour):0\(self.min):0\(self.sec).\(printMili)"
                    }else{
                        self.timerMSG.text = "0\(self.hour):0\(self.min):\(self.sec).\(printMili)"
                    }
                }else{
                    self.timerMSG.text = "0\(self.hour):\(self.min):\(self.sec).\(printMili)"
                }
            }else{
                self.timerMSG.text = "\(self.hour):\(self.min):\(self.sec).\(printMili)"
            }
        }
    }
    
    
    func setupMotion(){
        if CMPedometer.isPedometerEventTrackingAvailable(){
            self.pedometer = CMPedometer()
            pedometer?.startUpdates(from: Date()){(data, error) in
                guard let pedometerData = data, error == nil else { print("There was an error with the pedometer"); return}
                DispatchQueue.main.async {
                    self.pedometerMSG.text = pedometerData.numberOfSteps.stringValue
                    self.cadenceMSG.text = "\(String(describing: pedometerData.currentCadence))"
                    self.paceMSG.text = "\(String(describing: pedometerData.currentPace))"
                    self.distancePedometerMSG.text = "\(String(describing: pedometerData.distance))"
                }
            }
        }else{
            DispatchQueue.main.async {
                self.pedometerMSG.text = "No Pedometer"
            }
            print("The current device does not have a pedometer")
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)// if there is an error grabbing the locations this will print it
    }
    
    //MARK: - Watch session delegate methods
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        self.isActive = true
    }
    
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        //Heart rate data was sent back
        if let Rate = message["BPM"] as? Double{
            self.hearRateAVG.append(Rate)
            DispatchQueue.main.async {
                self.heartRate.text = String(Rate)
            }
        }
        
        //calorire data was sent back
        if let Cals = message["CAL"] as? Double{
            DispatchQueue.main.async {
                self.calorieMSG.text = String(Cals)
            }
            self.totalCalories = Cals
        }
    }
    
}

