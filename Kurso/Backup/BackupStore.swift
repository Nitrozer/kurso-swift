import Foundation
import SwiftData
import KursoCore
import KursoModels

/// Fabrique et relit la sauvegarde complete.
///
/// Les fichiers hors base — PDF importes, audio des cours — voyagent avec :
/// une sauvegarde qui ne rendrait que la base laisserait des diapos vides et
/// des enregistrements muets.
enum BackupStore {

    @MainActor
    static func archive(_ context: ModelContext) -> Backup.Archive {
        func all<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }

        return Backup.Archive(
            courses: all(Course.self).map { course in
                .init(id: course.id, name: course.name, colorToken: course.colorToken,
                      coverStyle: course.coverStyle, icsUID: course.icsUID,
                      teacher: course.teacher, archivedAt: course.archivedAt,
                      seasonID: course.season?.id)
            },
            pages: all(Page.self).map { page in
                .init(id: page.id, title: page.title, titleWasEdited: page.titleWasEdited,
                      position: page.position, templateRaw: page.templateRaw,
                      createdAt: page.createdAt, writingSeconds: page.writingSeconds,
                      markdown: page.markdown, recognizedText: page.recognizedText,
                      sessionEnd: page.sessionEnd, sprintProposedAt: page.sprintProposedAt,
                      masteredAt: page.masteredAt, drawing: page.drawing, photo: page.photo,
                      photoX: page.photoBox?.x, photoY: page.photoBox?.y,
                      photoW: page.photoBox?.width, photoH: page.photoBox?.height,
                      pdfAssetID: page.pdfAssetID, pdfPageIndex: page.pdfPageIndex,
                      courseID: page.course?.id)
            },
            cards: all(Card.self).map { card in
                .init(id: card.id, kindRaw: card.kindRaw, question: card.question,
                      answerText: card.answerText, answerDrawing: card.answerDrawing,
                      imageData: card.imageData, occX: card.occlusion?.x, occY: card.occlusion?.y,
                      occW: card.occlusion?.width, occH: card.occlusion?.height,
                      sourceLineStart: card.sourceLineStart, sourceLineEnd: card.sourceLineEnd,
                      interval: card.interval, ease: card.ease, dueAt: card.dueAt,
                      lapses: card.lapses, isInMistakeBook: card.isInMistakeBook,
                      pageID: card.page?.id)
            },
            images: all(PageImage.self).map { image in
                .init(id: image.id, data: image.data, x: image.x, y: image.y,
                      width: image.width, height: image.height, order: image.order,
                      pageID: image.page?.id)
            },
            assets: all(PDFAsset.self).map { asset in
                .init(id: asset.id, fileName: asset.fileName, title: asset.title,
                      pageCount: asset.pageCount, importedAt: asset.importedAt,
                      file: try? Data(contentsOf: PDFStore.url(for: asset.fileName)))
            },
            recordings: all(AudioRecording.self).map { recording in
                .init(id: recording.id, fileName: recording.fileName,
                      startedAt: recording.startedAt, durationSeconds: recording.durationSeconds,
                      marks: recording.strokeTimestamps.map {
                          .init(strokeID: $0.strokeID, offsetSeconds: $0.offsetSeconds,
                                anchorX: $0.anchorX, anchorY: $0.anchorY)
                      },
                      pageID: recording.page?.id,
                      file: audioData(recording.fileName))
            },
            assignments: all(Assignment.self).map { task in
                .init(id: task.id, title: task.title, dueAt: task.dueAt,
                      wasProposed: task.wasProposed, isDone: task.isDone, pageID: task.page?.id)
            },
            seasons: all(Season.self).map { season in
                .init(id: season.id, name: season.name, startsAt: season.startsAt,
                      examDate: season.examDate, closedAt: season.closedAt,
                      finalAcquiredPercent: season.finalAcquiredPercent,
                      finalPagesCount: season.finalPagesCount,
                      finalWritingHours: season.finalWritingHours, grade: season.grade)
            },
            slots: all(TimeSlot.self).map { slot in
                .init(id: slot.id, icsUID: slot.icsUID, summary: slot.summary,
                      location: slot.location, start: slot.start, end: slot.end,
                      recurrenceRule: slot.recurrenceRule, courseID: slot.course?.id)
            },
            player: all(PlayerState.self).first.map { state in
                .init(xp: state.xp, level: state.level, streak: state.streak,
                      recordStreak: state.recordStreak, gommesRemaining: state.gommesRemaining,
                      freezesRemaining: state.freezesRemaining, shavings: state.shavings,
                      displayName: state.displayName,
                      hasCompletedOnboarding: state.hasCompletedOnboarding,
                      lastStreakDay: state.lastStreakDay, ownedCovers: state.ownedCovers,
                      lastChestLevel: state.lastChestLevel,
                      writingSecondsAtLevel: state.writingSecondsAtLevel)
            }
        )
    }

    /// Ecrit la sauvegarde et rend son URL, prete a partager.
    @MainActor
    static func write(_ context: ModelContext) throws -> URL {
        let data = try Backup.encode(archive(context))
        let url = URL.temporaryDirectory.appending(path: Backup.fileName())
        try data.write(to: url)
        return url
    }

    /// Remplace TOUT le contenu par celui de la sauvegarde.
    ///
    /// Remplacer et non fusionner : fusionner deux versions d'une meme page
    /// demanderait l'ecran de conflit du §8, qui n'existe pas encore. Mieux
    /// vaut une regle nette qu'une fusion approximative sur des traits.
    @MainActor
    static func restore(_ archive: Backup.Archive, context: ModelContext) throws {
        try wipe(context)

        var seasons: [UUID: Season] = [:]
        for row in archive.seasons {
            let season = Season(name: row.name, startsAt: row.startsAt)
            season.id = row.id
            season.examDate = row.examDate
            season.closedAt = row.closedAt
            season.finalAcquiredPercent = row.finalAcquiredPercent
            season.finalPagesCount = row.finalPagesCount
            season.finalWritingHours = row.finalWritingHours
            season.grade = row.grade
            context.insert(season)
            seasons[row.id] = season
        }

        var courses: [UUID: Course] = [:]
        for row in archive.courses {
            let course = Course(name: row.name, colorToken: row.colorToken)
            course.id = row.id
            course.coverStyle = row.coverStyle
            course.icsUID = row.icsUID
            course.teacher = row.teacher
            course.archivedAt = row.archivedAt
            course.season = row.seasonID.flatMap { seasons[$0] }
            context.insert(course)
            courses[row.id] = course
        }

        var pages: [UUID: Page] = [:]
        for row in archive.pages {
            let page = Page(title: row.title, createdAt: row.createdAt)
            page.id = row.id
            page.titleWasEdited = row.titleWasEdited
            page.position = row.position
            page.templateRaw = row.templateRaw
            page.writingSeconds = row.writingSeconds
            page.markdown = row.markdown
            page.recognizedText = row.recognizedText
            page.sessionEnd = row.sessionEnd
            page.sprintProposedAt = row.sprintProposedAt
            page.masteredAt = row.masteredAt
            page.drawing = row.drawing
            page.photo = row.photo
            page.photoBox = rect(row.photoX, row.photoY, row.photoW, row.photoH)
            page.pdfAssetID = row.pdfAssetID
            page.pdfPageIndex = row.pdfPageIndex
            page.course = row.courseID.flatMap { courses[$0] }
            context.insert(page)
            pages[row.id] = page
        }

        for row in archive.cards {
            let card = Card(question: row.question, dueAt: row.dueAt)
            card.id = row.id
            card.kindRaw = row.kindRaw
            card.answerText = row.answerText
            card.answerDrawing = row.answerDrawing
            card.imageData = row.imageData
            card.occlusion = rect(row.occX, row.occY, row.occW, row.occH)
            card.sourceLineStart = row.sourceLineStart
            card.sourceLineEnd = row.sourceLineEnd
            card.interval = row.interval
            card.ease = row.ease
            card.lapses = row.lapses
            card.isInMistakeBook = row.isInMistakeBook
            card.page = row.pageID.flatMap { pages[$0] }
            context.insert(card)
        }

        for row in archive.images {
            let image = PageImage(data: row.data)
            image.id = row.id
            image.x = row.x; image.y = row.y
            image.width = row.width; image.height = row.height
            image.order = row.order
            image.page = row.pageID.flatMap { pages[$0] }
            context.insert(image)
        }

        for row in archive.assets {
            let asset = PDFAsset()
            asset.id = row.id
            asset.fileName = row.fileName
            asset.title = row.title
            asset.pageCount = row.pageCount
            asset.importedAt = row.importedAt
            context.insert(asset)
            if let file = row.file {
                try? FileManager.default.createDirectory(at: PDFStore.directory, withIntermediateDirectories: true)
                try? file.write(to: PDFStore.url(for: row.fileName))
            }
        }

        for row in archive.recordings {
            let recording = AudioRecording()
            recording.id = row.id
            recording.fileName = row.fileName
            recording.startedAt = row.startedAt
            recording.durationSeconds = row.durationSeconds
            recording.strokeTimestamps = row.marks.map {
                StrokeTimestamp(strokeID: $0.strokeID, offsetSeconds: $0.offsetSeconds,
                                anchorX: $0.anchorX, anchorY: $0.anchorY)
            }
            recording.page = row.pageID.flatMap { pages[$0] }
            context.insert(recording)
            if let file = row.file { writeAudio(file, named: row.fileName) }
        }

        for row in archive.assignments {
            let task = Assignment(title: row.title)
            task.id = row.id
            task.dueAt = row.dueAt
            task.wasProposed = row.wasProposed
            task.isDone = row.isDone
            task.page = row.pageID.flatMap { pages[$0] }
            context.insert(task)
        }

        for row in archive.slots {
            let slot = TimeSlot()
            slot.id = row.id
            slot.icsUID = row.icsUID
            slot.summary = row.summary
            slot.location = row.location
            slot.start = row.start
            slot.end = row.end
            slot.recurrenceRule = row.recurrenceRule
            slot.course = row.courseID.flatMap { courses[$0] }
            context.insert(slot)
        }

        if let row = archive.player {
            let state = PlayerState()
            state.xp = row.xp; state.level = row.level
            state.streak = row.streak; state.recordStreak = row.recordStreak
            state.gommesRemaining = row.gommesRemaining
            state.freezesRemaining = row.freezesRemaining
            state.shavings = row.shavings
            state.displayName = row.displayName
            state.hasCompletedOnboarding = row.hasCompletedOnboarding
            state.lastStreakDay = row.lastStreakDay
            state.ownedCovers = row.ownedCovers
            state.lastChestLevel = row.lastChestLevel
            state.writingSecondsAtLevel = row.writingSecondsAtLevel
            context.insert(state)
        }

        try context.save()
    }

    @MainActor
    private static func wipe(_ context: ModelContext) throws {
        try context.delete(model: Card.self)
        try context.delete(model: PageImage.self)
        try context.delete(model: AudioRecording.self)
        try context.delete(model: Assignment.self)
        try context.delete(model: Page.self)
        try context.delete(model: TimeSlot.self)
        try context.delete(model: Course.self)
        try context.delete(model: PDFAsset.self)
        try context.delete(model: Season.self)
        try context.delete(model: PlayerState.self)
        try context.delete(model: ExamSnapshot.self)
        try context.delete(model: ExamPaper.self)
        try context.save()
    }

    /// L'enregistreur n'existe que sur iPad ; la sauvegarde, sur les deux.
    @MainActor
    private static func audioData(_ fileName: String) -> Data? {
        #if os(iOS)
        return try? Data(contentsOf: LectureRecorder.url(for: fileName))
        #else
        return nil
        #endif
    }

    @MainActor
    private static func writeAudio(_ data: Data, named fileName: String) {
        #if os(iOS)
        try? FileManager.default.createDirectory(at: LectureRecorder.directory, withIntermediateDirectories: true)
        try? data.write(to: LectureRecorder.url(for: fileName))
        #endif
    }

    private static func rect(_ x: Double?, _ y: Double?, _ w: Double?, _ h: Double?) -> StoredRect? {
        guard let x, let y, let w, let h else { return nil }
        return StoredRect(x: x, y: y, width: w, height: h)
    }
}
