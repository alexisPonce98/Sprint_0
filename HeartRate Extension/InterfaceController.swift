//
//  InterfaceController.swift
//  HeartRate Extension
//
//  Created by Alexis Ponce on 6/10/21.
//

import WatchKit
import Foundation
import HealthKit
import WatchConnectivity

class InterfaceController: WKInterfaceController, WCSessionDelegate, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    
    @IBOutlet weak var workoutStartMSG: WKInterfaceLabel!
    
    
    @IBOutlet weak var calorieMSG: WKInterfaceLabel!
    @IBOutlet weak var heartRateMSG: WKInterfaceLabel!
    var session: WCSession?
    var store:HKHealthStore?
    let configuration = HKWorkoutConfiguration()
    var workoutSession: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    var currentWorkoutInProgress = false
    var startDate:Date?
    
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        if(WCSession.isSupported()){
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func setUpHealth(){
        if(HKHealthStore.isHealthDataAvailable()){
            self.currentWorkoutInProgress = true
            self.store = HKHealthStore()
            
            let shareType:Set = [HKWorkoutType.workoutType(), HKWorkoutType.quantityType(forIdentifier: .heartRate)!, HKSeriesType.workoutRoute(), HKWorkoutType.quantityType(forIdentifier: .activeEnergyBurned)!, HKWorkoutType.quantityType(forIdentifier: .distanceWalkingRunning)!]
            
            let readType:Set = [HKWorkoutType.workoutType(), (HKWorkoutType.quantityType(forIdentifier: .heartRate)!), HKSeriesType.workoutRoute(), HKWorkoutType.quantityType(forIdentifier: .activeEnergyBurned)!, HKWorkoutType.quantityType(forIdentifier: .distanceWalkingRunning)!]
            
            
            self.store?.requestAuthorization(toShare: shareType, read: readType){(success, error) in
                if(error != nil){
                    print("There was something wrong when requesting health Data")
                }
            }
            
            
            self.configuration.activityType = .running
            self.configuration.locationType = .outdoor
           
            do{
                self.workoutSession = try HKWorkoutSession(healthStore: self.store!, configuration: configuration)
                self.builder = (workoutSession?.associatedWorkoutBuilder())!
                
            }catch{
                print("Something wen wrong when creating the workout session and builder")
            }
            self.builder!.dataSource = HKLiveWorkoutDataSource(healthStore: self.store!, workoutConfiguration: configuration)
            self.workoutSession?.delegate = self
            self.builder!.delegate = self
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    //MARK: WCSession delegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let realMessage = message["Workout"] as? String{
            
            if(realMessage == "Start"){
                //start the apple watch workout
                self.setUpHealth()
                let sem = DispatchSemaphore(value: 0)
                self.workoutSession?.startActivity(with: Date())
                self.builder?.beginCollection(withStart: Date()){ (success, error) in
                        guard success else{
                            print("Something went wrong with starting to being the builder collection \(String(describing: error?.localizedDescription))")
                            return
                        }
                        DispatchQueue.main.async {
                            self.workoutStartMSG.setText("Workout Start")
                        }
                    sem.signal()
                    }
                sem.wait()
            }
        }
        if let realMSG = message["Workout1"] as? String{
            if(realMSG == "Stop"){
                self.workoutSession!.end()
                self.builder?.endCollection(withEnd: Date()){(success, error) in
                    guard success else{
                        print("Something happened when trying to end the collection of workout data for the builder: \(String(describing: error?.localizedDescription))")
                        return
                    }
                    
                    self.builder?.finishWorkout{(workout, error) in
                        guard workout != nil else{
                            print("Something went wrong when finishing the workout error code: \(String(describing: error?.localizedDescription))")
                            return
                        }
                        DispatchQueue.main.async {
                            self.workoutStartMSG.setText("Workout end")
                        }
                    }
                }
            }
        }
        if let tempStartDate = message["date"] as? Date{
            self.startDate = tempStartDate
        }
        
    }
    
    //MARK: workout session delegate methods
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
    
    
    //MARK: workout builder delegate methods
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes{
            guard let quantityType = type as? HKQuantityType else{
                print("Type collected is not quantitiy type")
                return
            }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            switch statistics?.quantityType{
                case HKObjectType.quantityType(forIdentifier: .heartRate):
                    guard let validSession = self.session else{
                        print("Something is wrong with the session")
                        return
                    }
                    let heartUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    let heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartUnit)
                    let dic:[String:Double] = ["BPM": heartRate!]
                    session?.sendMessage(dic, replyHandler: nil, errorHandler:{(error) in
                        if(error != nil){
                            print("Something went wrong sending the message to the heart rate to the phone")
                        }
                    })
                    DispatchQueue.main.async {
                        self.heartRateMSG.setText(String(heartRate!))
                    }
                    break
            case HKObjectType.quantityType(forIdentifier: .activeEnergyBurned):
                let calBurned  = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.largeCalorie())
                DispatchQueue.main.async {
                    self.calorieMSG.setText(String(calBurned!))
                }
                
                session?.sendMessage(["CAL": calBurned], replyHandler: nil, errorHandler: {(error) in
                    print("There was an error when sending the calories burned from the watch")
                })
                break
            case HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning):
                
                break
            default:
                break
            }
            
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        
    }
    
    
}
