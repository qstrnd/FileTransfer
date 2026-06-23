import Foundation

struct NameGenerator {
    struct Identity {
        let emoji: String
        let name: String
    }

    static func generate() -> Identity {
        let entry = entries.randomElement()!
        let adjective = entry.adjectives.randomElement()!
        return Identity(emoji: entry.emoji, name: "\(adjective) \(entry.noun)")
    }

    private struct Entry {
        let emoji: String
        let noun: String
        let adjectives: [String]
    }

    private static let entries: [Entry] = [
        Entry(emoji: "🐟", noun: "Fish",      adjectives: ["Fantastic", "Silver",    "Deep",      "Dazzling",  "Slippery"]),
        Entry(emoji: "🦁", noun: "Lion",      adjectives: ["Brave",     "Roaring",   "Golden",    "Wild",      "Proud"]),
        Entry(emoji: "🐺", noun: "Wolf",      adjectives: ["Lone",      "Howling",   "Shadow",    "Silver",    "Fierce"]),
        Entry(emoji: "🦊", noun: "Fox",       adjectives: ["Clever",    "Swift",     "Cunning",   "Amber",     "Sly"]),
        Entry(emoji: "🐻", noun: "Bear",      adjectives: ["Mighty",    "Grizzled",  "Gentle",    "Bold",      "Snowy"]),
        Entry(emoji: "🦅", noun: "Eagle",     adjectives: ["Soaring",   "Noble",     "Keen",      "Sky",       "Swift"]),
        Entry(emoji: "🦋", noun: "Butterfly", adjectives: ["Vivid",     "Drifting",  "Jade",      "Crimson",   "Ethereal"]),
        Entry(emoji: "🐉", noun: "Dragon",    adjectives: ["Crimson",   "Ancient",   "Storm",     "Jade",      "Blazing"]),
        Entry(emoji: "🌟", noun: "Star",      adjectives: ["Radiant",   "Blazing",   "Cosmic",    "Brilliant", "Stellar"]),
        Entry(emoji: "🌊", noun: "Wave",      adjectives: ["Crashing",  "Deep",      "Azure",     "Roaring",   "Silent"]),
        Entry(emoji: "🌙", noun: "Moon",      adjectives: ["Crescent",  "Silver",    "Pale",      "Glowing",   "Midnight"]),
        Entry(emoji: "☄️", noun: "Comet",     adjectives: ["Blazing",   "Streaking", "Cosmic",    "Radiant",   "Swift"]),
        Entry(emoji: "🌺", noun: "Blossom",   adjectives: ["Cherry",    "Scarlet",   "Fragrant",  "Gentle",    "Spring"]),
        Entry(emoji: "🦩", noun: "Flamingo",  adjectives: ["Pink",      "Elegant",   "Graceful",  "Tropical",  "Rosy"]),
        Entry(emoji: "🐙", noun: "Octopus",   adjectives: ["Clever",    "Inky",      "Elusive",   "Deep",      "Crimson"]),
        Entry(emoji: "🦈", noun: "Shark",     adjectives: ["Silent",    "Deep",      "Phantom",   "Storm",     "Apex"]),
        Entry(emoji: "🌵", noun: "Cactus",    adjectives: ["Desert",    "Sturdy",    "Prickly",   "Ancient",   "Silent"]),
        Entry(emoji: "🦚", noun: "Peacock",   adjectives: ["Vivid",     "Royal",     "Shimmering","Proud",     "Dazzling"]),
        Entry(emoji: "🐬", noun: "Dolphin",   adjectives: ["Swift",     "Playful",   "Blue",      "Leaping",   "Sleek"]),
        Entry(emoji: "🦉", noun: "Owl",       adjectives: ["Wise",      "Silent",    "Midnight",  "Ancient",   "Keen"]),
        Entry(emoji: "🐆", noun: "Leopard",   adjectives: ["Spotted",   "Swift",     "Shadow",    "Sleek",     "Phantom"]),
        Entry(emoji: "🦜", noun: "Parrot",    adjectives: ["Vivid",     "Chatty",    "Tropical",  "Bright",    "Clever"]),
        Entry(emoji: "🐳", noun: "Whale",     adjectives: ["Gentle",    "Deep",      "Ancient",   "Drifting",  "Blue"]),
        Entry(emoji: "🦝", noun: "Raccoon",   adjectives: ["Clever",    "Masked",    "Sneaky",    "Nimble",    "Bold"]),
        Entry(emoji: "🌈", noun: "Rainbow",   adjectives: ["Vivid",     "Arching",   "Brilliant", "Fleeting",  "Radiant"]),
    ]
}
