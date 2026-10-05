import AppIntents

enum FavoriteTeam: String, AppEnum {
    case ana = "ANA"
    case bos = "BOS"
    case buf = "BUF"
    case cgy = "CGY"
    case car = "CAR"
    case chi = "CHI"
    case col = "COL"
    case cbj = "CBJ"
    case dal = "DAL"
    case det = "DET"
    case edm = "EDM"
    case fla = "FLA"
    case lak = "LAK"
    case min = "MIN"
    case mtl = "MTL"
    case nsh = "NSH"
    case njd = "NJD"
    case nyi = "NYI"
    case nyr = "NYR"
    case ott = "OTT"
    case phi = "PHI"
    case pit = "PIT"
    case sjs = "SJS"
    case sea = "SEA"
    case stl = "STL"
    case tbl = "TBL"
    case tor = "TOR"
    case uta = "UTA"
    case van = "VAN"
    case vgk = "VGK"
    case wsh = "WSH"
    case wpg = "WPG"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Team"
    static var caseDisplayRepresentations: [FavoriteTeam: DisplayRepresentation] = [
        .ana: "Anaheim Ducks",
        .bos: "Boston Bruins",
        .buf: "Buffalo Sabres",
        .cgy: "Calgary Flames",
        .car: "Carolina Hurricanes",
        .chi: "Chicago Blackhawks",
        .col: "Colorado Avalanche",
        .cbj: "Columbus Blue Jackets",
        .dal: "Dallas Stars",
        .det: "Detroit Red Wings",
        .edm: "Edmonton Oilers",
        .fla: "Florida Panthers",
        .lak: "Los Angeles Kings",
        .min: "Minnesota Wild",
        .mtl: "Montréal Canadiens",
        .nsh: "Nashville Predators",
        .njd: "New Jersey Devils",
        .nyi: "New York Islanders",
        .nyr: "New York Rangers",
        .ott: "Ottawa Senators",
        .phi: "Philadelphia Flyers",
        .pit: "Pittsburgh Penguins",
        .sjs: "San Jose Sharks",
        .sea: "Seattle Kraken",
        .stl: "St. Louis Blues",
        .tbl: "Tampa Bay Lightning",
        .tor: "Toronto Maple Leafs",
        .uta: "Utah Mammoth",
        .van: "Vancouver Canucks",
        .vgk: "Vegas Golden Knights",
        .wsh: "Washington Capitals",
        .wpg: "Winnipeg Jets",
    ]
}
