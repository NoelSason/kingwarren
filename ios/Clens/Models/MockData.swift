import Foundation

enum Mock {
    static let warren = UserProfile(
        name: "Warren Park",
        handle: "@warrenp",
        points: 12_487,
        rank: "Tide Keeper",
        streak: 14,
        store: "Whole Foods Market",
        lastHaul: 431,
        lifetimeCO2: 184,
        lifetimePlastic: 2.1,
        lifetimeWater: 9_220
    )

    static let oceanToday = OceanConditions(
        location: "CCE2 mooring · San Diego shelf",
        updated: "2 hr ago",
        stressIndex: 1.34,
        chlorophyll: "+38%",
        pH: "-0.04",
        dissolvedO2: "-12%",
        headline: "Elevated algal bloom signal",
        detail: "Runoff-driven chlorophyll is 38% above seasonal mean. Low-fertilizer products earn 2× this week.",
        alert: "2× points on low-runoff produce"
    )

    static let products: [String: Product] = [
        "monster": Product(
            id: "monster",
            name: "Monster Energy Zero Sugar",
            brand: "Monster Energy",
            size: "16 fl oz",
            score: 38,
            category: "Beverage · Canned",
            breakdown: .init(climate: 42, runoff: 18, plastic: 62, water: 55),
            facts: ["Aluminum can (recyclable)", "Processed, long shipped", "No fertilizer runoff load"],
            origin: "Corona, CA · shipped 1,840 mi",
            badges: ["Poor"]
        ),
        "avocado": Product(
            id: "avocado",
            name: "Hass Avocado",
            brand: "Mission Produce",
            size: "each",
            score: 71,
            category: "Produce · Fresh",
            breakdown: .init(climate: 72, runoff: 64, plastic: 95, water: 38),
            facts: ["No packaging", "High water footprint (320 L/kg)", "Imported from Michoacán"],
            origin: "Michoacán, MX · shipped 1,600 mi",
            badges: ["Good"]
        ),
        "beef": Product(
            id: "beef",
            name: "Ground Beef 80/20",
            brand: "Harris Ranch",
            size: "1 lb",
            score: 14,
            category: "Meat · Refrigerated",
            breakdown: .init(climate: 8, runoff: 12, plastic: 48, water: 6),
            facts: ["High CO\u{2082} (27 kg/kg)", "Feed crops drive fertilizer runoff", "Algal bloom contributor"],
            origin: "Coalinga, CA · shipped 420 mi",
            badges: ["Very Poor"]
        ),
        "oats": Product(
            id: "oats",
            name: "Rolled Oats, Organic",
            brand: "Bob's Red Mill",
            size: "32 oz",
            score: 88,
            category: "Grain · Dry",
            breakdown: .init(climate: 92, runoff: 85, plastic: 76, water: 94),
            facts: ["Low-input dry crop", "Paper packaging", "Regional sourcing (OR)"],
            origin: "Milwaukie, OR · shipped 1,100 mi",
            badges: ["Excellent"]
        ),
        "lentils": Product(
            id: "lentils",
            name: "Green Lentils, Bulk",
            brand: "Bulk Bin",
            size: "per lb",
            score: 94,
            category: "Legume · Dry",
            breakdown: .init(climate: 96, runoff: 92, plastic: 100, water: 92),
            facts: ["Nitrogen-fixing crop (reduces fertilizer need)", "Bring-your-own container", "Low water"],
            origin: "Pullman, WA · shipped 1,280 mi",
            badges: ["Excellent", "2× today"]
        ),
        "tofu": Product(
            id: "tofu",
            name: "Organic Firm Tofu",
            brand: "Hodo",
            size: "14 oz",
            score: 82,
            category: "Plant Protein",
            breakdown: .init(climate: 88, runoff: 78, plastic: 70, water: 86),
            facts: ["Organic soy (no synthetic fert.)", "Plastic tub", "Local SF bay sourcing"],
            origin: "Oakland, CA · shipped 120 mi",
            badges: ["Excellent"]
        )
    ]

    static let receipt = Receipt(
        store: "Whole Foods Market · La Jolla",
        date: "Apr 16, 2026 · 6:42 PM",
        total: 68.42,
        items: [
            ReceiptItem(name: "Ground Beef 80/20", price: 9.99, pid: "beef"),
            ReceiptItem(name: "Hass Avocado (3)", price: 4.47, pid: "avocado"),
            ReceiptItem(name: "Monster Zero 16oz", price: 3.49, pid: "monster"),
            ReceiptItem(name: "Organic Rolled Oats", price: 5.99, pid: "oats"),
            ReceiptItem(name: "Organic Firm Tofu", price: 4.29, pid: "tofu"),
            ReceiptItem(name: "Green Lentils, bulk", price: 2.18, pid: "lentils")
        ],
        earned: 431,
        averageScore: 64
    )

    static let swaps: [String: Swap] = [
        "monster": Swap(
            from: "monster",
            to: "oats",
            altName: "Cold-Brew Oat Bev, 32oz",
            deltaScore: 34,
            deltaPoints: 84,
            pros: ["No aluminum mining", "Lower shipping distance", "No added taurine farming"],
            cons: ["Not a caffeine kick", "Higher unit price"]
        ),
        "beef": Swap(
            from: "beef",
            to: "lentils",
            altName: "Green Lentils (2 lb)",
            deltaScore: 80,
            deltaPoints: 220,
            pros: ["Nitrogen-fixing crop cuts fertilizer", "Direct hit on bloom driver today", "12× less CO\u{2082}/kg"],
            cons: ["Different protein profile", "Longer cook time"]
        )
    ]

    static let feed: [FeedItem] = [
        .haul(
            who: "Warren",
            amount: 431,
            where_: "Whole Foods Market",
            time: "Today · 6:42 PM",
            detail: "6 items · Avg. Ocean Score 64"
        ),
        .ocean(
            headline: oceanToday.headline,
            detail: oceanToday.detail,
            time: "Updated 2 hr ago"
        ),
        .nudge(
            headline: "You could have gained +220",
            detail: "Swapping ground beef for lentils today would've earned 2× runoff bonus.",
            action: "See swap"
        ),
        .friend(
            who: "Aarav",
            action: "overtook you on the weekly board",
            detail: "Aarav is +112 ahead. Scan a receipt to catch up.",
            time: "1h ago"
        )
    ]

    static let rewards: [Reward] = [
        Reward(brand: "Patagonia Provisions", title: "$15 off smoked mussels", cost: 4_000, tag: "Ocean-positive", featured: true),
        Reward(brand: "Blue Apron", title: "Free low-carbon box", cost: 9_500, tag: "Plant-forward", featured: false),
        Reward(brand: "Ridwell", title: "3 months pickup", cost: 7_200, tag: "Plastic", featured: false),
        Reward(brand: "REI Co-op", title: "$20 gift card", cost: 12_000, tag: "Outdoors", featured: false),
        Reward(brand: "Imperfect Foods", title: "20% off first box", cost: 2_800, tag: "Food waste", featured: false),
        Reward(brand: "Clens", title: "Seaside weekend giveaway entry", cost: 500, tag: "Raffle", featured: false)
    ]

    static let leaders: [Leader] = [
        Leader(name: "Mira K.", rank: 1, pts: 18_902, area: "La Jolla", tag: "Reef Guardian", isMe: false),
        Leader(name: "Aarav S.", rank: 2, pts: 12_599, area: "UTC", tag: "Tide Keeper", isMe: false),
        Leader(name: "Warren Park", rank: 3, pts: 12_487, area: "La Jolla", tag: "Tide Keeper", isMe: true),
        Leader(name: "Noel R.", rank: 4, pts: 11_840, area: "Pacific Beach", tag: "Tide Keeper", isMe: false),
        Leader(name: "Shaun L.", rank: 5, pts: 10_215, area: "UTC", tag: "Current Reader", isMe: false),
        Leader(name: "Dana F.", rank: 6, pts: 9_102, area: "North Park", tag: "Current Reader", isMe: false),
        Leader(name: "Jules O.", rank: 7, pts: 8_440, area: "OB", tag: "Current Reader", isMe: false)
    ]
}
