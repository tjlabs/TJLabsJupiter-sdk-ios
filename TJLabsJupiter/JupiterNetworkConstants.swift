
import Foundation

let TIMEOUT_VALUE_PUT: TimeInterval = 5.0

public class JupiterNetworkConstants {
    static let USER_SERVER_VERSION = "2024-06-12"
    static let REC_SERVER_VERSION = "2024-04-19"
    
    private static let HTTP_PREFIX = "https://"
    private static let JUPITER_SUFFIX = ".jupiter.tjlabs.dev"
    
    private(set) static var REGION_PREFIX = "ap-northeast-2."
    private(set) static var REGION_NAME = "Korea"
    
    private(set) static var USER_URL = HTTP_PREFIX + REGION_PREFIX + "user" + JUPITER_SUFFIX
    private(set) static var IMAGE_URL = HTTP_PREFIX + REGION_PREFIX + "img" + JUPITER_SUFFIX
    private(set) static var CSV_URL = HTTP_PREFIX + REGION_PREFIX + "csv" + JUPITER_SUFFIX
    private(set) static var REC_URL = HTTP_PREFIX + REGION_PREFIX + "rec" + JUPITER_SUFFIX
    private(set) static var CALC_URL = HTTP_PREFIX + REGION_PREFIX + "calc" + JUPITER_SUFFIX
    private(set) static var CLIENT_URL = HTTP_PREFIX + REGION_PREFIX + "client" + JUPITER_SUFFIX
    
    public static func setServerURL(region: JupiterRegion) {
        switch region {
        case .KOREA:
            REGION_PREFIX = "ap-northeast-2."
            REGION_NAME = "Korea"
        case .CANADA:
            REGION_PREFIX = "ca-central-1."
            REGION_NAME = "Canada"
        case .US:
            REGION_PREFIX = "us-east-1."
            REGION_NAME = "US"
        }
        
        USER_URL = HTTP_PREFIX + REGION_PREFIX + "user" + JUPITER_SUFFIX
        IMAGE_URL = HTTP_PREFIX + REGION_PREFIX + "img" + JUPITER_SUFFIX
        CSV_URL = HTTP_PREFIX + REGION_PREFIX + "csv" + JUPITER_SUFFIX
        REC_URL = HTTP_PREFIX + REGION_PREFIX + "rec" + JUPITER_SUFFIX
        CALC_URL = HTTP_PREFIX + REGION_PREFIX + "calc" + JUPITER_SUFFIX
        CLIENT_URL = HTTP_PREFIX + REGION_PREFIX + "client" + JUPITER_SUFFIX
    }
    
    public static func getUserVersion() -> String {
        return USER_SERVER_VERSION
    }
    
    public static func getUserBaseURL() -> String {
        return USER_URL
    }
    
    public static func getRecBaseURL() -> String {
        return REC_URL
    }
    
    public static func getRecServerVersion() -> String {
        return REC_SERVER_VERSION
    }
}
