//
//  StatisticsViewController.swift
//  TelegramContest
//
//  Created by Philip on 3/16/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class ParentCell: UITableViewCell {
    class var reuseIdentifier: String { return "" }
    
    var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            backgroundColor = presentationTheme.cellBackgroundColor
        }
    }
}


class StatisticsViewController: UIViewController {
    private static let themeUDKey = "isDarkTheme"
    
    private static let chartCellHeight: CGFloat = 309
    private static let chartSliderCellHeight: CGFloat = 64
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navigationBarView: UIView!
    @IBOutlet weak var navigationBarSeparatorView: UIView!
    @IBOutlet weak var navigationBarTitleLabel: UILabel!
    @IBOutlet weak var switchThemeButton: UIButton!
    
    var charts = [ChartData]()
    var visibleSegments = [Segment]()
    var selectedDates = [Int:TimeInterval]()
    var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            presentationThemeUpdated()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBarSeparatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        let isDark = UserDefaults.standard.bool(forKey: StatisticsViewController.themeUDKey) == true
        presentationTheme = isDark ? PresentationTheme.nightTheme : PresentationTheme.dayTheme
        
        let cacheFilePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cache")
        var data: Data?
        if let path = Bundle.main.path(forResource: "cache", ofType: nil) {
            data = try? Data(contentsOf: URL(fileURLWithPath: path))
        }
        if data == nil {
            data = try? Data(contentsOf: cacheFilePath)
        }
        if let data = data,
            let charts = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [ChartData]
        {
            self.charts = charts
        }
        else if let contestDirPath = Bundle.main.path(forResource: "contest 2", ofType: nil) {
            charts = ChartData.parse(rootDir: URL(fileURLWithPath: contestDirPath))!
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: charts, requiringSecureCoding: false) {
                try? data.write(to: cacheFilePath)
                print("cached \(cacheFilePath)")
            }
        }
        charts.swapAt(0, 4)
        visibleSegments = Array(repeating: Segment(start: 0.67, end: 1), count: charts.count)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return presentationTheme?.statusBarStyle ?? super.preferredStatusBarStyle
    }
    
    func presentationThemeUpdated() {
        tableView.backgroundColor = presentationTheme.tableViewBackgroundColor
        tableView.visibleCells.forEach { ($0 as? ParentCell)?.presentationTheme = presentationTheme }
        navigationBarView.backgroundColor = presentationTheme.cellBackgroundColor
        navigationBarTitleLabel.textColor =  presentationTheme.selectionTitleTextColor
        navigationBarSeparatorView.backgroundColor = presentationTheme.navigationBarSeparatorColor
        setNeedsStatusBarAppearanceUpdate()
        switchThemeButton.setTitle(presentationTheme.switchThemeText, for: .normal)
        switchThemeButton.setTitleColor(presentationTheme.switchThemeTextColor, for: .normal)
    }
    
    @IBAction func switchThemeButtonHandler(_ sender: Any) {
        presentationTheme = presentationTheme.isDark ? PresentationTheme.dayTheme : PresentationTheme.nightTheme
        UserDefaults.standard.set(presentationTheme.isDark, forKey: StatisticsViewController.themeUDKey)
    }
}

extension StatisticsViewController: UITableViewDataSource {    
    func numberOfSections(in tableView: UITableView) -> Int {
        return charts.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return charts[section].dataSets.count > 1 ? 3 : 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ParentCell
        switch indexPath.row {
        case 0:
            cell = tableView.dequeueReusableCell(withIdentifier: ChartTableViewCell.reuseIdentifier) as! ChartTableViewCell
            
        case 1:
            cell = tableView.dequeueReusableCell(withIdentifier: SliderTableViewCell.reuseIdentifier) as! SliderTableViewCell
            
        default:
            cell = tableView.dequeueReusableCell(withIdentifier: SelectionTableViewCell.reuseIdentifier) as! SelectionTableViewCell
        }
        configure(cell: cell, forRowAt: indexPath)
        return cell
    }
    
    private func configure(cell: ParentCell, forRowAt indexPath: IndexPath) {
        cell.presentationTheme = presentationTheme
        guard indexPath.section < charts.count else { return }
        let chart = charts[indexPath.section]
        
        let visibleSegment = visibleSegments[indexPath.section]
        switch indexPath.row {
        case 0:
            let cell = cell as! ChartTableViewCell
            
            cell.chartView.chartData = chart
            cell.chartView.visibleSegment = visibleSegment
            cell.chartView.selectedDate = selectedDates[indexPath.section]
            cell.chartView.selectedDateChangedHandler = { [weak self] (selectedDate) in
                self?.selectedDates[indexPath.section] = selectedDate
            }
            return
            
        case 1:
            let cell = cell as! SliderTableViewCell
            
            cell.sliderView.setSelectedValues(minValue: CGFloat(visibleSegment.start),
                                              maxValue: CGFloat(visibleSegment.end))
            cell.manager.chartData = chart
            cell.manager.visibleSegment = Segment(start: 0, end: 1)
            cell.valueChangedHandler = { [weak self] in
                let segment = Segment(start: TimeInterval(cell.sliderView!.minSelectedValue),
                                      end: TimeInterval(cell.sliderView!.maxSelectedValue))
                self?.visibleSegments[indexPath.section] = segment
                let chartCell = self?.tableView.cellForRow(at: IndexPath(row: 0, section: indexPath.section)) as? ChartTableViewCell
                chartCell?.chartView.visibleSegment = segment
            }
            return
            
        default:
            let cell = cell as! SelectionTableViewCell
            cell.chartDataSets = chart.dataSets
            cell.selectionChangedHandler = { [weak self] index in
                guard let strongSelf = self else { return }
                
                if !strongSelf.charts[indexPath.section].dataSets[index].selected ||
                    strongSelf.charts[indexPath.section].dataSets.enumerated().first(where: { $0.0 != index && $0.1.selected }) != nil
                {
                    strongSelf.charts[indexPath.section].dataSets[index].selected = !strongSelf.charts[indexPath.section].dataSets[index].selected
                    strongSelf.charts[indexPath.section].selectionUpdated()
                }
                else {
                    let alertVC = UIAlertController(title: "At least one chart should be selected",
                                                    message: nil,
                                                    preferredStyle: .alert)
                    alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    strongSelf.present(alertVC, animated: true, completion: nil)
                    return
                }
                cell.update()
                for indexPath in [
                    IndexPath(row: 0, section: indexPath.section),
                    IndexPath(row: 1, section: indexPath.section)
                    ]
                {
                    if let cell = strongSelf.tableView.cellForRow(at: indexPath) as? ParentCell {
                        strongSelf.configure(cell: cell, forRowAt: indexPath)
                    }
                }

            }
            return
        }
    }
}

extension StatisticsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < charts.count else { return nil }
        let view = UIView()
        let label = UILabel()
        view.addSubview(label)
        
        let attributedString = NSMutableAttributedString(string: charts[section].name)
        attributedString.addAttribute(NSAttributedString.Key.kern, value: 0.05, range: NSMakeRange(0, attributedString.length))
        label.attributedText = attributedString
        
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = presentationTheme.headerTextColor
        label.sizeToFit()
        label.frame = CGRect(origin: CGPoint(x: 15, y: 30), size: label.frame.size)
        view.frame = CGRect(x: 0, y: 0, width: label.frame.maxX, height: label.frame.maxY + 8)
                
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.tableView(tableView, viewForHeaderInSection: section)?.frame.height ?? 0
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section < charts.count {
            if indexPath.row == 0 {
                return StatisticsViewController.chartCellHeight
            }
            if indexPath.row == 1 {
                return StatisticsViewController.chartSliderCellHeight
            }
            return 20 + SelectionTableViewCell.height(for: charts[indexPath.section].dataSets,
                                                      maxWidth: view.bounds.width - view.layoutMargins.left - view.layoutMargins.right)
        }
        return 46
    }
}
