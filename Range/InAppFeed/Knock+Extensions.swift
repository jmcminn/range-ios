import Foundation
import Knock
import SWXMLHash

extension Knock.FeedItem {
    var actionUrl: URL? {
        guard let path = (blocks.first(where: { $0.name == "action_url" }) as? Knock.TextContentBlock)?.rendered
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return URL(string: "https://range.io\(path)")
    }

    enum ParsedBodyClass: String, CaseIterable {
        case project, subject, label, message

        static func bodyClass(forString: String) -> ParsedBodyClass? {
            ParsedBodyClass.allCases.first { $0.rawValue == forString }
        }
    }

    /// Parses the feed item "body" block
    /// It assumes that the block has a form of:
    ///
    /// <p class="project">The Preserve</p>
    /// <p class="subject"><b>PRES-102 • Paint defect</b></p>
    /// <p class="label">Jeff Goldberg says</p>
    /// <p class="message"><blockquote>Jeff Goldberg removed the due date</blockquote></p>
    /// <p class="message"><blockquote>Jeff Goldberg updated the due date from 2024-03-05 to 2024-03-15</blockquote></p>
    ///
    /// The parser expects a number of top level <p> elements with classes as defined in `ParsedBodyClass`.
    /// For each such <p> element it takes its text and constructs a list of texts with their classes and stores in a copy of FeedItem (as self
    /// is immutable) in the data["parsedBody"]
    ///
    /// The output from the example above is:
    /// [
    ///     (.project, "The Preserve"),
    ///     (.subject, "PRES-102 • Paint defect"),
    ///     (.label, "Jeff Goldberg says"),
    ///     (.message, "Jeff Goldberg removed the due date")
    ///     (.message, "Jeff Goldberg updated the due date from 2024-03-05 to 2024-03-15")
    /// ]
    func _withParsedBody() -> Knock.FeedItem {
        guard let body = (blocks.first(where: { $0.name == "body" }) as? Knock.MarkdownContentBlock)?.rendered
        else { return self }
        let bodyXML = XMLHash.parse("<root>\(body)</root>")

        var parsedBody: [(ParsedBodyClass, String)] = bodyXML["root"].children.compactMap { p in
            guard p.element?.name == "p",
                  let pClassString = p.element?.attribute(by: "class")?.text,
                  let pClass = ParsedBodyClass.bodyClass(forString: pClassString),
                  let text = p.element?.recursiveText else { return nil }

            return (pClass, text)
        }

        // fallback value created by concatenating the text for all elements in the body
        // (to show something for backward compatibility)
        if parsedBody.isEmpty {
            let fallbackText: String = bodyXML["root"].children.compactMap { $0.element?.recursiveText }
                .joined(separator: "\n")
            parsedBody.append((.message, fallbackText))
        }

        // copy self and update the data["parsedBody"]
        var dataCopy = data
        dataCopy?["parsedBody"] = AnyCodable(parsedBody)
        return Knock.FeedItem(
            __cursor: __cursor, actors: actors, activities: activities, blocks: blocks,
            data: dataCopy, id: id, inserted_at: inserted_at, interacted_at: interacted_at,
            clicked_at: clicked_at, link_clicked_at: link_clicked_at, read_at: read_at,
            seen_at: seen_at, tenant: tenant, total_activities: total_activities,
            total_actors: total_actors, updated_at: updated_at
        )
    }
}

/// Async functions
public extension Knock {
    func _updateMessageStatus(messageId: String, status: KnockMessageStatusUpdateType) async throws {
        // Knock API calls the handler 2 times in case of some errors!
        var resumed = false
        try await withCheckedThrowingContinuation { continuation in
            self.updateMessageStatus(messageId: messageId, status: status) { result in
                if resumed == false {
                    resumed = true
                    switch result {
                    case .success: continuation.resume()
                    case let .failure(error): continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func _getUserPreferences(preferenceId: String) async throws -> PreferenceSet {
        // Knock API calls the handler 2 times in case of some errors!
        var resumed = false
        return try await withCheckedThrowingContinuation { continuation in
            self.getUserPreferences(preferenceId: preferenceId) { result in
                if resumed == false {
                    resumed = true
                    switch result {
                    case let .success(preferenceSet): continuation.resume(returning: preferenceSet)
                    case let .failure(error): continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func _setUserPreferences(preferenceId: String, preferenceSet: PreferenceSet) async throws -> PreferenceSet {
        // Knock API calls the handler 2 times in case of some errors!
        var resumed = false
        return try await withCheckedThrowingContinuation { continuation in
            self.setUserPreferences(preferenceId: preferenceId, preferenceSet: preferenceSet) { result in
                if resumed == false {
                    resumed = true
                    switch result {
                    case let .success(preferenceSet): continuation.resume(returning: preferenceSet)
                    case let .failure(error): continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

/// Async functions
public extension Knock.FeedManager {
    func _getUserFeedContent(options: Knock.FeedClientOptions? = nil) async throws -> Knock.Feed {
        // Knock API calls the handler 2 times in case of some errors!
        var resumed = false
        return try await withCheckedThrowingContinuation { continuation in
            self.getUserFeedContent(options: options) { result in
                if resumed == false {
                    resumed = true
                    switch result {
                    case let .success(feed): continuation.resume(returning: feed)
                    case let .failure(error): continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func _makeBulkStatusUpdate(
        type: Knock.BulkChannelMessageStatusUpdateType,
        options: Knock.FeedClientOptions
    ) async throws {
        // Knock API calls the handler 2 times in case of some errors!
        var resumed = false
        try await withCheckedThrowingContinuation { continuation in
            self.makeBulkStatusUpdate(type: type, options: options) { result in
                if resumed == false {
                    resumed = true
                    switch result {
                    case .success: continuation.resume()
                    case let .failure(error): continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
