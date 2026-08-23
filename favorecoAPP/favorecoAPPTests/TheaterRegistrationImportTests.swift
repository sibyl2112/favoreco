import XCTest
@testable import favoreco

final class TheaterRegistrationImportTests: XCTestCase {
    func testMajorTicketHostsAreSeparatedFromOfficialSites() throws {
        let ticketURLs = [
            "https://tiget.net/events/514629",
            "https://eplus.jp/sf/detail/0000000001",
            "https://t.pia.jp/pia/event/event.do?eventCd=0001",
            "https://l-tike.com/order/?gLcode=00001",
            "https://t.livepocket.jp/e/sample",
            "https://ticket.tickebo.jp/sn/sample/",
            "https://www.confetti-web.com/events/17246",
            "https://stagegate.jp/sample",
            "https://ticketdive.com/event/ImaginaryLine",
            "https://peatix.com/event/1234567",
            "https://eventregist.com/e/sample",
        ]

        for rawURL in ticketURLs {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertTrue(
                URLMetadataService.isTicketingURLForTesting(url),
                "Expected ticket site classification for \(rawURL)"
            )
        }

        let officialURL = try XCTUnwrap(URL(string: "https://www.egopression.com/"))
        XCTAssertFalse(URLMetadataService.isTicketingURLForTesting(officialURL))
    }

    func testPosterOCRCombinesProminentTitleAndFindsVenueAndPeriod() {
        let referenceDate = date(2026, 7, 28)
        let result = QuickCaptureImageService.inferredFieldsForTesting(
            lines: [
                ("HORIPRO", 0.12, 0.025),
                ("どこか", 0.18, 0.11),
                ("奇妙な", 0.19, 0.11),
                ("職業体験", 0.28, 0.14),
                ("夜の学校調査員", 0.46, 0.09),
                ("会場 千代田中学校・高等学校", 0.44, 0.035),
                ("開催日時 8月21日・23日・28日・30日", 0.52, 0.034),
            ],
            referenceDate: referenceDate
        )

        XCTAssertEqual(
            result.titleCandidates.first,
            "どこか奇妙な職業体験　夜の学校調査員"
        )
        XCTAssertEqual(result.venueCandidates.first, "千代田中学校・高等学校")
        XCTAssertEqual(result.eventDateRange?.startsAt, date(2026, 8, 21))
        XCTAssertEqual(result.eventDateRange?.endsAt, date(2026, 8, 30))
    }

    func testPosterOCRFindsUnlabeledEnglishVenueAddressAndExplicitYearRange() {
        let result = QuickCaptureImageService.inferredFieldsForTesting(
            lines: [
                ("Dressers / Dressers Live Theater presents", 0.54, 0.025),
                ("冬の結婚式", 0.52, 0.12),
                ("2026年7月28日(火)〜8月2日(日) 8公演", 0.58, 0.034),
                ("MONSTER THEATER ROPPONGI", 0.51, 0.032),
                ("東京都港区六本木5-9-22 第2千陽ビル4階", 0.57, 0.025),
            ],
            referenceDate: date(2025, 12, 1)
        )

        XCTAssertEqual(result.titleCandidates.first, "冬の結婚式")
        XCTAssertEqual(result.venueCandidates.first, "MONSTER THEATER ROPPONGI")
        XCTAssertEqual(result.addressCandidates.first, "東京都港区六本木5-9-22 第2千陽ビル4階")
        XCTAssertEqual(result.eventDateRange?.startsAt, date(2026, 7, 28))
        XCTAssertEqual(result.eventDateRange?.endsAt, date(2026, 8, 2))
    }

    func testPosterOCRFindsMultilineScheduleAndRestaurantVenue() {
        let result = QuickCaptureImageService.inferredFieldsForTesting(
            lines: [
                ("ESPACT × ビストロおむすび目黒", 0.43, 0.028),
                ("おいしいアマーンプ", 0.76, 0.15),
                ("極上のおいしいイマーシブをご提供させていただきます。", 0.68, 0.022),
                ("2026年8月14日(金) 19:00", 0.43, 0.032),
                ("15日(土) 17:00", 0.29, 0.032),
                ("16日(日) 17:00", 0.29, 0.032),
                ("ビストロおむすび目黒", 0.35, 0.034),
                ("〒153-0064 東京都目黒区下目黒1丁目5-16", 0.58, 0.021),
                ("目黒サンライズマンション2F 203", 0.38, 0.021),
            ],
            referenceDate: date(2026, 8, 1)
        )

        XCTAssertEqual(result.titleCandidates.first, "おいしいイマーシブ")
        XCTAssertEqual(result.venueCandidates.first, "ビストロおむすび目黒")
        XCTAssertEqual(
            result.addressCandidates.first,
            "東京都目黒区下目黒1丁目5-16 目黒サンライズマンション2F 203"
        )
        XCTAssertEqual(result.eventDateRange?.startsAt, date(2026, 8, 14))
        XCTAssertEqual(result.eventDateRange?.endsAt, date(2026, 8, 16))
    }

    func testOGPMetadataReadsTitleAndImageRegardlessOfAttributeOrder() {
        let html = """
        <html><head>
        <meta content="https://example.com/poster.jpg" property="og:image">
        <meta property="og:title" content="どこか奇妙な職業体験 &amp; 夜の学校調査員">
        </head></html>
        """

        let metadata = URLMetadataService.htmlMetadataForTesting(in: html)

        XCTAssertEqual(metadata.title, "どこか奇妙な職業体験 & 夜の学校調査員")
        XCTAssertEqual(metadata.imageURLString, "https://example.com/poster.jpg")
    }

    func testTicketMetadataReadsItempropDatesAndEventVenueWithoutJSONLD() {
        let html = """
        <html><head>
        <meta itemprop="startDate" content="2026-12-05T18:30:00+09:00">
        <meta content="2026-12-05T21:00:00+09:00" itemprop="endDate">
        <meta property="event:location" content="東京芸術劇場 プレイハウス">
        </head></html>
        """

        let metadata = URLMetadataService.structuredMetadataForTesting(
            in: html,
            sourceURL: URL(string: "https://ticket.pia.jp/pia/event.ds?eventCd=sample")!
        )

        XCTAssertEqual(metadata.date, date(2026, 12, 5, 18, 30))
        XCTAssertEqual(metadata.venueName, "東京芸術劇場 プレイハウス")
        XCTAssertEqual(metadata.purchaseURL?.host, "ticket.pia.jp")
        XCTAssertNil(metadata.officialURL)
    }

    func testTicketSiteFallbackExtractsLabeledEventInformationFromDescription() {
        let html = """
        <html><head>
        <meta property="og:description" content="開催日：2026年9月29日(火)
        会場：東京カルチャーカルチャー
        出演者：
        MC 堀江聖夏
        イソメン倶楽部 / ALL IN / KAJA
        -------------------------------------------------------------
        イベント公式サイト：https://rrgo.info/
        主催：RADIO！READY GO！実行委員会
        企画：株式会社FAIR NEXT INNOVATION
        制作：Makee（株式会社grabss）
        協力：TIGET">
        <script type="application/ld+json">
        {
          "@type": "Event",
          "startDate": "2026年09月29日(火)T15:15:+0900", // invalid JSON comment
          "location": { "name": "東京カルチャーカルチャー" }
        }
        </script>
        </head></html>
        """

        let metadata = URLMetadataService.structuredMetadataForTesting(
            in: html,
            sourceURL: URL(string: "https://tiget.net/events/514629")!
        )

        XCTAssertEqual(metadata.date, date(2026, 9, 29, 15, 15))
        XCTAssertEqual(metadata.venueName, "東京カルチャーカルチャー")
        XCTAssertEqual(metadata.officialURL?.absoluteString, "https://rrgo.info/")
        XCTAssertEqual(metadata.purchaseURL?.absoluteString, "https://tiget.net/events/514629")
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "organizer" && $0.name == "RADIO！READY GO！実行委員会"
        })
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "planning" && $0.name == "株式会社FAIR NEXT INNOVATION"
        })
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "production" && $0.name == "Makee（株式会社grabss）"
        })
        XCTAssertTrue(metadata.creditsText.contains("出演者："))
        XCTAssertTrue(metadata.creditsText.contains("イソメン倶楽部 / ALL IN / KAJA"))
    }

    func testOfficialEventPageKeepsSourceAsOfficialURL() {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type":"Event","organizer":{"name":"月影劇団"},"performer":{"name":"空野ミオ"}}
        </script>
        <meta name="description" content="会場：新国立劇場">
        </head></html>
        """
        let sourceURL = URL(string: "https://example-theater.jp/performances/moon")!

        let metadata = URLMetadataService.structuredMetadataForTesting(
            in: html,
            sourceURL: sourceURL
        )

        XCTAssertEqual(metadata.officialURL, sourceURL)
        XCTAssertNil(metadata.purchaseURL)
        XCTAssertEqual(metadata.venueName, "新国立劇場")
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "organizer" && $0.name == "月影劇団"
        })
        XCTAssertTrue(metadata.creditsText.contains("主催：月影劇団"))
        XCTAssertTrue(metadata.creditsText.contains("出演：空野ミオ"))
    }

    func testCollapsedTicketDescriptionStillSeparatesAdjacentLabels() {
        let html = """
        <html><head>
        <meta property="og:description" content="開催日：2026年9月29日(火) 15:15 会場：東京カルチャーカルチャー イベント公式サイト：https://rrgo.info/=====主催：RADIO！READY GO！実行委員会 企画：株式会社FAIR NEXT INNOVATION 制作：Makee（株式会社grabss） 協力：TIGET">
        </head></html>
        """

        let metadata = URLMetadataService.structuredMetadataForTesting(
            in: html,
            sourceURL: URL(string: "https://tiget.net/events/514629")!
        )

        XCTAssertEqual(metadata.date, date(2026, 9, 29, 15, 15))
        XCTAssertEqual(metadata.venueName, "東京カルチャーカルチャー")
        XCTAssertEqual(metadata.officialURL?.absoluteString, "https://rrgo.info/")
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "organizer" && $0.name == "RADIO！READY GO！実行委員会"
        })
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "planning" && $0.name == "株式会社FAIR NEXT INNOVATION"
        })
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "production" && $0.name == "Makee（株式会社grabss）"
        })
    }

    func testConfettiPublicEventResponseMapsPageFieldsWithoutHTMLAccess() throws {
        let data = try XCTUnwrap(
            """
            {
              "data": {
                "eventForPublic": {
                  "name": "舞台『アーク・レクイエム～黎明ノ章～』【一般先行】",
                  "thumbnailUrl": "https://assets.confetti-web.com/uploads/events/17246/poster.png",
                  "startDate": "2026-11-11T00:00:00.000Z",
                  "endDate": "2026-11-15T00:00:00.000Z",
                  "displayVenueName": null,
                  "organization": null,
                  "masterVenue": { "name": "六行会ホール", "masterVenue": null },
                  "eventInformation": {
                    "link": "https://actorsbattle-fc.com/",
                    "cast": "新井將\\n佐藤弘樹",
                    "staff": "脚本・演出：吉田武寛\\n企画製作：株式会社Beyond Zero Project"
                  }
                }
              }
            }
            """.data(using: .utf8)
        )
        let sourceURL = try XCTUnwrap(
            URL(string: "https://www.confetti-web.com/events/17246?utm_source=mail")
        )

        let metadata = try XCTUnwrap(
            URLMetadataService.confettiMetadataForTesting(in: data, sourceURL: sourceURL)
        )

        XCTAssertEqual(metadata.title, "舞台『アーク・レクイエム～黎明ノ章～』【一般先行】")
        XCTAssertEqual(metadata.resolvedURL.absoluteString, "https://www.confetti-web.com/events/17246")
        XCTAssertEqual(metadata.purchaseURL?.absoluteString, "https://www.confetti-web.com/events/17246")
        XCTAssertEqual(metadata.officialURL?.absoluteString, "https://actorsbattle-fc.com/")
        XCTAssertEqual(metadata.venueName, "六行会ホール")
        XCTAssertEqual(metadata.imageURL?.absoluteString, "https://assets.confetti-web.com/uploads/events/17246/poster.png")
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "production" && $0.name == "株式会社Beyond Zero Project"
        })
        XCTAssertTrue(metadata.creditsText.contains("出演者：\n新井將\n佐藤弘樹"))
        XCTAssertTrue(metadata.creditsText.contains("スタッフ："))
    }

    func testTicketDiveUsesEmbeddedEventImageAndSeparatesOfficialFromTicketURL() throws {
        let payload: [String: Any] = [
            "props": [
                "pageProps": [
                    "__superjsonProps": [
                        "json": [
                            "eventDetail": [
                                "event": [
                                    "name": "ego:pression presents イマーシブシアター「イマジナリーライン」",
                                    "detail": """
                                    【会場】
                                    pia 板橋工場（東京都板橋区本蓮沼町45-4）
                                    【公式】
                                    Web：https://www.egopression.com/
                                    """,
                                    "topImage": "https://storage.googleapis.com/playyte-ticket-prod_event/main.webp",
                                    "inquiry": "株式会社ego:pression（egopression@gmail.com）",
                                ],
                                "stages": [
                                    [
                                        "startStage": "2026-11-14T03:00:00.000Z",
                                        "venue": ["name": "pia 板橋工場"],
                                        "artists": [["name": "秋吉朝子"], ["name": "eat_"]],
                                    ],
                                    [
                                        "startStage": "2026-12-06T05:30:00.000Z",
                                        "venue": ["name": "pia 板橋工場"],
                                        "artists": [["name": "秋吉朝子"], ["name": "Mana"]],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
        let html = "<html><head><meta property=\"og:image\" content=\"https://ticketdive.com/generic-logo.webp\"><script id=\"__NEXT_DATA__\" type=\"application/json\">\(json)</script></head></html>"
        let sourceURL = try XCTUnwrap(
            URL(string: "https://ticketdive.com/event/ImaginaryLine?utm_source=share")
        )

        let metadata = try XCTUnwrap(
            URLMetadataService.ticketDiveMetadataForTesting(in: html, sourceURL: sourceURL)
        )

        XCTAssertEqual(metadata.title, "ego:pression presents イマーシブシアター「イマジナリーライン」")
        XCTAssertEqual(metadata.resolvedURL.absoluteString, "https://ticketdive.com/event/ImaginaryLine")
        XCTAssertEqual(metadata.purchaseURL?.absoluteString, "https://ticketdive.com/event/ImaginaryLine")
        XCTAssertEqual(metadata.officialURL?.absoluteString, "https://www.egopression.com/")
        XCTAssertEqual(metadata.imageURL?.absoluteString, "https://storage.googleapis.com/playyte-ticket-prod_event/main.webp")
        XCTAssertEqual(metadata.venueName, "pia 板橋工場")
        XCTAssertEqual(metadata.venueAddress, "東京都板橋区本蓮沼町45-4")
        XCTAssertEqual(metadata.eventDate, date(2026, 11, 14, 12))
        XCTAssertEqual(metadata.eventEndDate, date(2026, 12, 6, 14, 30))
        XCTAssertTrue(metadata.contributors.contains {
            $0.roleKey == "organizer" && $0.name == "株式会社ego:pression"
        })
        XCTAssertTrue(metadata.creditsText.contains("秋吉朝子\neat_\nMana"))
    }

    func testEventTicketURLRoundTripsWithoutChangingLegacyData() {
        let fields = VisitUnitFields(eventTicketURL: "https://tiget.net/events/514629")
        let decoded = VisitUnitFields(rawValue: fields.encodedRawValue)
        let legacy = VisitUnitFields(rawValue: #"{"eventCreditsText":"主催：月影劇団"}"#)

        XCTAssertEqual(decoded.eventTicketURL, "https://tiget.net/events/514629")
        XCTAssertEqual(legacy.eventTicketURL, "")
        XCTAssertEqual(legacy.eventCreditsText, "主催：月影劇団")
    }

    func testCreditOCRParsesCharacterAndStaffLinesIntoIndividualCandidates() {
        let parsed = TheaterCreditTextParser.parse("""
        出演
        アベル：松原凛
        ルドガー・ペンドラゴン：黒木文貴
        照明：和田優也
        音響：佐藤克幸
        """)

        XCTAssertEqual(parsed.count, 4)
        XCTAssertEqual(parsed[0].name, "松原凛")
        XCTAssertEqual(parsed[0].role.key, "cast")
        XCTAssertEqual(parsed[0].roleDetail, "アベル")
        XCTAssertEqual(parsed[2].name, "和田優也")
        XCTAssertEqual(parsed[2].role.key, "lighting")
        XCTAssertEqual(parsed[2].roleDetail, "")
        XCTAssertEqual(parsed[3].role.key, "sound")
    }

    func testCreditOCRParsesStandaloneEnsembleNamesAndSkipsNotes() {
        let parsed = TheaterCreditTextParser.parse("""
        アンサンブルキャスト
        佐野遥喜
        竜崎新大
        ※この役のみ、役名は初日まで非公開。
        """)

        XCTAssertEqual(parsed.map(\.name), ["佐野遥喜", "竜崎新大"])
        XCTAssertTrue(parsed.allSatisfy { $0.role.key == "cast" })
    }

    func testCreditOCRJoinsWrappedParentheticalPersonName() {
        let parsed = TheaterCreditTextParser.parse("""
        衣装（クレイン、アンサンブル）：春奈
        （心-Shin）
        """)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "春奈（心-Shin）")
        XCTAssertEqual(parsed[0].role.key, "costume")
        XCTAssertEqual(parsed[0].roleDetail, "クレイン、アンサンブル")
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
