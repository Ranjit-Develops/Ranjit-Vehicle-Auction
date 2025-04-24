Config = {}

Config.AuctionHouse = {
    Ped = {
        model = "a_m_m_business_01",
        coords = vector4(1241.95, -3267.23, 5.53, 263.98),
        scenario = "WORLD_HUMAN_CLIPBOARD"
    },
    Blip = {
        sprite = 659,
        color = 5,
        scale = 0.8,
        label = "Vehicle Auction House"
    },
    PreviewSpot = vector4(1256.74, -3259.45, 5.8, 176.21)
}

Config.Camera = {
    defaultPos = vector3(1229.56, 2737.01, 40.0),
    defaultRot = vector3(-25.0, 0.0, 90.0),
    minZoom = 2.0,
    maxZoom = 10.0,
    zoomSpeed = 0.5,
    rotationSpeed = 2.0,
    defaultFov = 50.0,
    minFov = 30.0,
    maxFov = 80.0
}

Config.VehiclePool = {
    sports = {
        { name = "Adder", model = "adder" },
        { name = "Banshee", model = "banshee" },
        { name = "Buffalo", model = "buffalo" },
        { name = "Carbonizzare", model = "carbonizzare" },
        { name = "Comet", model = "comet2" },
        { name = "Elegy", model = "elegy2" },
        { name = "Feltzer", model = "feltzer2" },
        { name = "Jester", model = "jester" },
        { name = "Kuruma", model = "kuruma" },
    },
    super = {
        { name = "Bullet", model = "bullet" },
        { name = "Cheetah", model = "cheetah" },
        { name = "Entity XF", model = "entityxf" },
        { name = "FMJ", model = "fmj" },
        { name = "Osiris", model = "osiris" },
        { name = "T20", model = "t20" },
        { name = "Turismo R", model = "turismor" },
        { name = "Tyrus", model = "tyrus" },
        { name = "Vacca", model = "vacca" },
        { name = "Zentorno", model = "zentorno" },
    },
    sedans = {
        { name = "Asea", model = "asea" },
        { name = "Asterope", model = "asterope" },
        { name = "Cognoscenti", model = "cognoscenti" },
        { name = "Emperor", model = "emperor" },
        { name = "Fugitive", model = "fugitive" },
        { name = "Glendale", model = "glendale" },
        { name = "Ingot", model = "ingot" },
        { name = "Intruder", model = "intruder" },
        { name = "Premier", model = "premier" },
    },
    suvs = {
        { name = "Baller", model = "baller" },
        { name = "Cavalcade", model = "cavalcade" },
        { name = "Granger", model = "granger" },
        { name = "Huntley S", model = "huntley" },
        { name = "Landstalker", model = "landstalker" },
        { name = "Radius", model = "radi" },
        { name = "Rocoto", model = "rocoto" },
        { name = "Seminole", model = "seminole" },
        { name = "XLS", model = "xls" },
    },
    muscle = {
        { name = "Blade", model = "blade" },
        { name = "Buccaneer", model = "buccaneer" },
        { name = "Dominator", model = "dominator" },
        { name = "Dukes", model = "dukes" },
        { name = "Gauntlet", model = "gauntlet" },
        { name = "Hotknife", model = "hotknife" },
        { name = "Phoenix", model = "phoenix" },
        { name = "Picador", model = "picador" },
        { name = "Sabre Turbo", model = "sabregt" },
        { name = "Vigero", model = "vigero" },
    },
    motorcycles = {
        { name = "Akuma", model = "akuma" },
        { name = "Bagger", model = "bagger" },
        { name = "Bati 801", model = "bati" },
        { name = "Carbon RS", model = "carbonrs" },
        { name = "Double T", model = "double" },
        { name = "Hakuchou", model = "hakuchou" },
        { name = "Hexer", model = "hexer" },
        { name = "PCJ-600", model = "pcj" },
        { name = "Ruffian", model = "ruffian" },
        { name = "Thrust", model = "thrust" },
    }
}

Config.EnablePreviewInAdmin = true
Config.MinimumBidIncrement = 2400
Config.BidCooldownSeconds = 5
Config.ClaimExpirationDays = 7

Config.Webhooks = {
    AuctionCreated = "https://discord.com/api/webhooks/1337837910715535430/GiOnjVE2WuMCTXxeC4p3bmawjVqlTvNQVSd2r1Shrb11BPE2PWzowqLVihZwClEBNU1K",
    BidPlaced = "https://discord.com/api/webhooks/1337837910715535430/GiOnjVE2WuMCTXxeC4p3bmawjVqlTvNQVSd2r1Shrb11BPE2PWzowqLVihZwClEBNU1K",
    AuctionCompleted = "https://discord.com/api/webhooks/1337837910715535430/GiOnjVE2WuMCTXxeC4p3bmawjVqlTvNQVSd2r1Shrb11BPE2PWzowqLVihZwClEBNU1K"
}

Config.Colors = {
    Green = 65280,
    Yellow = 16776960,
    Red = 16711680,
    Blue = 255
}

