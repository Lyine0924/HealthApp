//
//  RecordViewController.swift
//  HealthApp
//
//  Created by Moisés Córdova on 7/7/19.
//  Copyright © 2019 Moisés Córdova. All rights reserved.
//

import UIKit
import Charts

class RecordViewController: UIViewController {
    var records: [BasicRecord] = []
    var myRecords: [AnyObject] = [] //참고 할 부분
    var mainColor: UIColor!
    var mainIcon: UIImage!
    var recordTitle: String!
    let days = ["sun", "mon", "tue", "wed", "thur"]
    var barChartView: BarChartView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.barStyle = .default
        self.navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: mainColor!]
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: mainColor!]
        createBasicRecords()
    }
    
    func createChart(dataPoints: [String], values: [Double]) {
        var dataEntries: [BarChartDataEntry] = []
        for i in 0..<values.count {
            let dataEntry = BarChartDataEntry(x: Double(i), y: Double(values[i]))
            dataEntries.append(dataEntry)
        }
        let chartDataSet = BarChartDataSet(entries: dataEntries, label: "")
        let chartData = BarChartData(dataSet: chartDataSet)
        
        barChartView.data = chartData
        chartDataSet.colors = [#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)]
        barChartView.leftAxis.enabled = false
        barChartView.rightAxis.drawGridLinesEnabled = false
        barChartView.legend.enabled = false
        
        
        barChartView.animate(xAxisDuration: 2.0, yAxisDuration: 2.0)
    }
    
    // MARK = 선택한 레코드 타입에 따른 데이터 파싱
    func createBasicRecords() {
        if let healthRecords = myRecords as? [HearthRecord] {
            let sortedRecords = healthRecords.sorted(by: {$0.endDate > $1.endDate})
            for hearthRecord in sortedRecords {
                records.append(BasicRecord(record: "\(hearthRecord.bpm)", date: hearthRecord.endDate.formattedDate, data: Double(hearthRecord.bpm)))
            }
            return
        }
        
        if let healthRecords = myRecords as? [WorkoutRecord] {
            let sortedRecords = healthRecords.sorted(by: {$0.endDate > $1.endDate})
            for workoutRecord in sortedRecords {
                records.append(BasicRecord(record: "\(workoutRecord.calories.withoutDecimals)", date: workoutRecord.endDate.formattedDate, data: workoutRecord.calories))
            }
            return
        }
        
        if let healthRecords = myRecords as? [SleepAnalisys] {
            let sortedRecords = healthRecords.sorted(by: {$0.startDate > $1.startDate})
            for sleepRecord in sortedRecords {
                records.append(BasicRecord(record: "\(sleepRecord.hoursSleeping)", date: sleepRecord.startDate.formattedDate, data: Double(sleepRecord.hoursElapsed)))
            }
            return
        }
        
        if let foods = myRecords as? [Food] {
            let sortedRecords = foods.sorted(by: {$0.startDate > $1.startDate})
            for food in sortedRecords {
                records.append(BasicRecord(record: "\(food.name) - \(food.kilocalories.withoutDecimals) cal", date: food.startDate.formattedDate, data: food.kilocalories))
            }
        }
    }
    
    @IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension RecordViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return records.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            var data = [Double]()
            let cell = tableView.dequeueReusableCell(withIdentifier: "RecordMainCell", for: indexPath) as! RecordMainTableViewCell
            self.barChartView = cell.barChartView
            let values = records.suffix(6)
            
            for value in values {
                data.append(value.data)
            }
            
            self.createChart(dataPoints: days, values: data)
            cell.cardView.backgroundColor = mainColor
            cell.titleRecord.text = recordTitle
            cell.dateRecord.text = "Last Records"
            cell.imageRecord.image = mainIcon
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordCell", for: indexPath)
        cell.textLabel?.text = records[indexPath.row].record
        cell.detailTextLabel?.text = records[indexPath.row].date
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 300.0
        } else {
            return UITableView.automaticDimension
        }
    }
    
}
