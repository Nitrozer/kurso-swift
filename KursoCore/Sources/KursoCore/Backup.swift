import Foundation

/// La sauvegarde complete, et son format.
///
/// CloudKit est desactive tant que le compte developpeur ne l'est pas : les
/// cahiers n'existent donc aujourd'hui qu'a un seul endroit, sur l'iPad. Un
/// appareil perdu, c'est un semestre perdu. Ce format est l'assurance en
/// attendant, et il reste utile apres : il se lit sans Kurso.
///
/// Tout est ici, y compris les traits, les images, les PDF et l'audio. Un
/// format qui oublie une piece donne une fausse securite, ce qui est pire que
/// pas de sauvegarde du tout.
public enum Backup {

    /// On versionne des maintenant : une sauvegarde se relit des mois plus
    /// tard, quand le schema a bouge.
    public static let currentVersion = 1

    public struct Archive: Codable, Equatable, Sendable {
        public var version: Int
        public var createdAt: Date
        public var courses: [CourseRow]
        public var pages: [PageRow]
        public var cards: [CardRow]
        public var images: [ImageRow]
        /// FACULTATIF, et c'est indispensable : Swift exige toutes les cles
        /// d'un tableau non optionnel, meme avec une valeur par defaut — une
        /// archive ecrite avant les blocs de texte deviendrait illisible.
        public var texts: [TextRow]?
        public var assets: [AssetRow]
        public var recordings: [RecordingRow]
        public var assignments: [AssignmentRow]
        public var seasons: [SeasonRow]
        public var slots: [SlotRow]
        public var player: PlayerRow?

        public init(
            version: Int = Backup.currentVersion,
            createdAt: Date = .now,
            courses: [CourseRow] = [], pages: [PageRow] = [], cards: [CardRow] = [],
            images: [ImageRow] = [], texts: [TextRow]? = nil,
            assets: [AssetRow] = [], recordings: [RecordingRow] = [],
            assignments: [AssignmentRow] = [], seasons: [SeasonRow] = [], slots: [SlotRow] = [],
            player: PlayerRow? = nil
        ) {
            self.version = version
            self.createdAt = createdAt
            self.courses = courses
            self.pages = pages
            self.cards = cards
            self.images = images
            self.texts = texts
            self.assets = assets
            self.recordings = recordings
            self.assignments = assignments
            self.seasons = seasons
            self.slots = slots
            self.player = player
        }

        /// De quoi annoncer ce que contient un fichier avant de le restaurer.
        public var summary: String {
            "\(pages.count) page\(pages.count > 1 ? "s" : "") · \(courses.count) cahier\(courses.count > 1 ? "s" : "") · \(cards.count) carte\(cards.count > 1 ? "s" : "")"
        }
    }

    public struct CourseRow: Codable, Equatable, Sendable {
        public var id: UUID, name: String, colorToken: String, coverStyle: String
        public var icsUID: String?, teacher: String?, archivedAt: Date?, seasonID: UUID?
        public init(id: UUID, name: String, colorToken: String, coverStyle: String,
                    icsUID: String?, teacher: String?, archivedAt: Date?, seasonID: UUID?) {
            self.id = id; self.name = name; self.colorToken = colorToken
            self.coverStyle = coverStyle; self.icsUID = icsUID; self.teacher = teacher
            self.archivedAt = archivedAt; self.seasonID = seasonID
        }
    }

    public struct PageRow: Codable, Equatable, Sendable {
        public var id: UUID, title: String, titleWasEdited: Bool, position: Double
        public var templateRaw: String, createdAt: Date, writingSeconds: Int, markdown: String
        public var recognizedText: String
        public var sessionEnd: Date?, sprintProposedAt: Date?, masteredAt: Date?
        public var drawing: Data?, photo: Data?
        public var photoX: Double?, photoY: Double?, photoW: Double?, photoH: Double?
        public var pdfAssetID: UUID?, pdfPageIndex: Int?, courseID: UUID?
        /// Facultatif : une archive ecrite avant les intercalaires n'en porte
        /// pas, et elle doit continuer de se relire.
        public var tagToken: String?
        public init(id: UUID, title: String, titleWasEdited: Bool, position: Double,
                    templateRaw: String, createdAt: Date, writingSeconds: Int, markdown: String,
                    recognizedText: String, sessionEnd: Date?, sprintProposedAt: Date?,
                    masteredAt: Date?, drawing: Data?, photo: Data?,
                    photoX: Double?, photoY: Double?, photoW: Double?, photoH: Double?,
                    pdfAssetID: UUID?, pdfPageIndex: Int?, courseID: UUID?,
                    tagToken: String? = nil) {
            self.id = id; self.title = title; self.titleWasEdited = titleWasEdited
            self.position = position; self.templateRaw = templateRaw; self.createdAt = createdAt
            self.writingSeconds = writingSeconds; self.markdown = markdown
            self.recognizedText = recognizedText; self.sessionEnd = sessionEnd
            self.sprintProposedAt = sprintProposedAt; self.masteredAt = masteredAt
            self.drawing = drawing; self.photo = photo
            self.photoX = photoX; self.photoY = photoY; self.photoW = photoW; self.photoH = photoH
            self.pdfAssetID = pdfAssetID; self.pdfPageIndex = pdfPageIndex; self.courseID = courseID
            self.tagToken = tagToken
        }
    }

    public struct CardRow: Codable, Equatable, Sendable {
        public var id: UUID, kindRaw: String, question: String
        public var answerText: String?, answerDrawing: Data?, imageData: Data?
        public var occX: Double?, occY: Double?, occW: Double?, occH: Double?
        public var sourceLineStart: Int?, sourceLineEnd: Int?
        public var interval: Int, ease: Double, dueAt: Date, lapses: Int, isInMistakeBook: Bool
        public var pageID: UUID?
        public init(id: UUID, kindRaw: String, question: String, answerText: String?,
                    answerDrawing: Data?, imageData: Data?, occX: Double?, occY: Double?,
                    occW: Double?, occH: Double?, sourceLineStart: Int?, sourceLineEnd: Int?,
                    interval: Int, ease: Double, dueAt: Date, lapses: Int,
                    isInMistakeBook: Bool, pageID: UUID?) {
            self.id = id; self.kindRaw = kindRaw; self.question = question
            self.answerText = answerText; self.answerDrawing = answerDrawing
            self.imageData = imageData; self.occX = occX; self.occY = occY
            self.occW = occW; self.occH = occH; self.sourceLineStart = sourceLineStart
            self.sourceLineEnd = sourceLineEnd; self.interval = interval; self.ease = ease
            self.dueAt = dueAt; self.lapses = lapses; self.isInMistakeBook = isInMistakeBook
            self.pageID = pageID
        }
    }

    public struct ImageRow: Codable, Equatable, Sendable {
        public var id: UUID, data: Data?, x: Double, y: Double, width: Double, height: Double
        public var order: Double, pageID: UUID?
        public init(id: UUID, data: Data?, x: Double, y: Double, width: Double,
                    height: Double, order: Double, pageID: UUID?) {
            self.id = id; self.data = data; self.x = x; self.y = y
            self.width = width; self.height = height; self.order = order; self.pageID = pageID
        }
    }

    /// Un bloc de texte tape au clavier. Le RTF voyage avec : sans lui, on
    /// retrouverait le texte nu, sans sa mise en forme.
    public struct TextRow: Codable, Equatable, Sendable {
        public var id: UUID, rtf: Data?, plain: String
        public var x: Double, y: Double, width: Double, height: Double
        public var order: Double, pageID: UUID?
        public init(id: UUID, rtf: Data?, plain: String, x: Double, y: Double,
                    width: Double, height: Double, order: Double, pageID: UUID?) {
            self.id = id; self.rtf = rtf; self.plain = plain
            self.x = x; self.y = y; self.width = width; self.height = height
            self.order = order; self.pageID = pageID
        }
    }

    /// Un PDF importe : ses octets voyagent avec, sinon les diapos reviennent
    /// vides apres restauration.
    public struct AssetRow: Codable, Equatable, Sendable {
        public var id: UUID, fileName: String, title: String, pageCount: Int
        public var importedAt: Date, file: Data?
        public init(id: UUID, fileName: String, title: String, pageCount: Int,
                    importedAt: Date, file: Data?) {
            self.id = id; self.fileName = fileName; self.title = title
            self.pageCount = pageCount; self.importedAt = importedAt; self.file = file
        }
    }

    public struct RecordingRow: Codable, Equatable, Sendable {
        public struct Mark: Codable, Equatable, Sendable {
            public var strokeID: UUID, offsetSeconds: Double, anchorX: Double, anchorY: Double
            public init(strokeID: UUID, offsetSeconds: Double, anchorX: Double, anchorY: Double) {
                self.strokeID = strokeID; self.offsetSeconds = offsetSeconds
                self.anchorX = anchorX; self.anchorY = anchorY
            }
        }
        public var id: UUID, fileName: String, startedAt: Date, durationSeconds: Double
        public var marks: [Mark], pageID: UUID?, file: Data?
        public init(id: UUID, fileName: String, startedAt: Date, durationSeconds: Double,
                    marks: [Mark], pageID: UUID?, file: Data?) {
            self.id = id; self.fileName = fileName; self.startedAt = startedAt
            self.durationSeconds = durationSeconds; self.marks = marks
            self.pageID = pageID; self.file = file
        }
    }

    public struct AssignmentRow: Codable, Equatable, Sendable {
        public var id: UUID, title: String, dueAt: Date?, wasProposed: Bool, isDone: Bool
        public var pageID: UUID?
        public init(id: UUID, title: String, dueAt: Date?, wasProposed: Bool,
                    isDone: Bool, pageID: UUID?) {
            self.id = id; self.title = title; self.dueAt = dueAt
            self.wasProposed = wasProposed; self.isDone = isDone; self.pageID = pageID
        }
    }

    public struct SeasonRow: Codable, Equatable, Sendable {
        public var id: UUID, name: String, startsAt: Date
        public var examDate: Date?, closedAt: Date?
        public var finalAcquiredPercent: Double?, finalPagesCount: Int?
        public var finalWritingHours: Double?, grade: Double?
        public init(id: UUID, name: String, startsAt: Date, examDate: Date?, closedAt: Date?,
                    finalAcquiredPercent: Double?, finalPagesCount: Int?,
                    finalWritingHours: Double?, grade: Double?) {
            self.id = id; self.name = name; self.startsAt = startsAt
            self.examDate = examDate; self.closedAt = closedAt
            self.finalAcquiredPercent = finalAcquiredPercent
            self.finalPagesCount = finalPagesCount
            self.finalWritingHours = finalWritingHours; self.grade = grade
        }
    }

    public struct SlotRow: Codable, Equatable, Sendable {
        public var id: UUID, icsUID: String, summary: String, location: String?
        public var start: Date, end: Date, recurrenceRule: String?, courseID: UUID?
        public init(id: UUID, icsUID: String, summary: String, location: String?,
                    start: Date, end: Date, recurrenceRule: String?, courseID: UUID?) {
            self.id = id; self.icsUID = icsUID; self.summary = summary
            self.location = location; self.start = start; self.end = end
            self.recurrenceRule = recurrenceRule; self.courseID = courseID
        }
    }

    public struct PlayerRow: Codable, Equatable, Sendable {
        public var xp: Int, level: Int, streak: Int, recordStreak: Int
        public var gommesRemaining: Int, freezesRemaining: Int, shavings: Int
        public var displayName: String, hasCompletedOnboarding: Bool
        public var lastStreakDay: Date?, ownedCovers: [String]
        public var lastChestLevel: Int, writingSecondsAtLevel: Int
        public init(xp: Int, level: Int, streak: Int, recordStreak: Int, gommesRemaining: Int,
                    freezesRemaining: Int, shavings: Int, displayName: String,
                    hasCompletedOnboarding: Bool, lastStreakDay: Date?, ownedCovers: [String],
                    lastChestLevel: Int, writingSecondsAtLevel: Int) {
            self.xp = xp; self.level = level; self.streak = streak
            self.recordStreak = recordStreak; self.gommesRemaining = gommesRemaining
            self.freezesRemaining = freezesRemaining; self.shavings = shavings
            self.displayName = displayName; self.hasCompletedOnboarding = hasCompletedOnboarding
            self.lastStreakDay = lastStreakDay; self.ownedCovers = ownedCovers
            self.lastChestLevel = lastChestLevel; self.writingSecondsAtLevel = writingSecondsAtLevel
        }
    }

    // MARK: Lecture et ecriture

    public enum Failure: Error, Equatable {
        case unreadable
        /// Une sauvegarde plus recente que l'application.
        case tooRecent(version: Int)
    }

    public static func encode(_ archive: Archive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Lisible a l'oeil : une sauvegarde qu'on ne peut pas inspecter
        // demande de faire confiance sans pouvoir verifier.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    public static func decode(_ data: Data) throws -> Archive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let archive = try? decoder.decode(Archive.self, from: data) else {
            throw Failure.unreadable
        }
        guard archive.version <= currentVersion else {
            throw Failure.tooRecent(version: archive.version)
        }
        return archive
    }

    /// Le nom du fichier propose au partage.
    public static func fileName(for date: Date = .now) -> String {
        let day = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "Kurso — sauvegarde \(day).kursobackup"
    }
}
