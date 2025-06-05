import Foundation

class Collector {
    
    static let shared: Collector = Collector()
    
    class CollectorSpan: Codable {
        let id: String
        let parentId: String?
        let name: String
        let startTime: Date
        var endTime: Date? = nil
        
        init(id: String, name: String, startTime: Date, endTime: Date? = nil, parentId: String? = nil) {
            self.id = id
            self.name = name
            self.startTime = startTime
            self.endTime = endTime
            self.parentId = parentId
        }
    }
    
    private var spans: [String: CollectorSpan] = [:]
    private let queue = DispatchQueue(label: "com.embrace.collector.span.queue")
    
    func startSpan(id: String, name: String, time: Date? = nil, parentId: String? = nil) {
        spans[id] = CollectorSpan(id: id, name: name, startTime: time ?? Date(), parentId: parentId)
    }
    
    func endSpan(id: String, time: Date? = nil) {
        spans[id]?.endTime = time ?? Date()
        
        if #available(iOS 16.0, *) {
            
            let copies = Array(spans.values).sorted { span1, span2 in
                span1.startTime < span2.startTime
            }
            queue.async {
                
                // JSON
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(copies) {
                    try? data.write(to: URL(filePath: "/Users/alex/Desktop/span.json"))
                }
                
                // CSV
                var csvString = copies.map { span in
                    "\(span.id),\(span.name),\(span.startTime.timeIntervalSince1970),\(span.endTime?.timeIntervalSince1970 ?? 0),\(span.parentId ?? "")"
                }.joined(separator: "\n")
                
                csvString = "id,name,start_time,end_time,parent_id\n" + csvString
                
                
                try? csvString.write(to: URL(filePath: "/Users/alex/Desktop/span.csv"), atomically: false, encoding: .utf8)
            }
        }
    }
}
