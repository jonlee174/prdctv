import Foundation
import SwiftData
import Testing

@MainActor
struct RewardEngineTests {
    @Test func zeroPointsEarnsNothing() {
        let engine = RewardEngine(needPointsDone: 0, redeemedWant: 0, redeemedFun: 0)
        #expect(engine.availableWant == 0)
        #expect(engine.availableFun == 0)
        #expect(engine.progressLabel(.want) == "0/4 toward Want")
    }

    @Test func leftoverPointsCarryOver() {
        let engine = RewardEngine(needPointsDone: 5, redeemedWant: 0, redeemedFun: 0)
        #expect(engine.earnedWant == 1)
        #expect(engine.progress(.want) == 1)
        #expect(engine.earnedFun == 0)
        #expect(engine.progress(.fun) == 5)
    }

    @Test func countersAreIndependent() {
        // 28 points = 7 Want and 4 Fun; spending Want doesn't touch Fun.
        let engine = RewardEngine(needPointsDone: 28, redeemedWant: 3, redeemedFun: 0)
        #expect(engine.availableWant == 4)
        #expect(engine.availableFun == 4)
        #expect(engine.progress(.want) == 0)
        #expect(engine.progress(.fun) == 0)
    }

    @Test func balanceCanGoNegativeAfterUncompleting() {
        let engine = RewardEngine(needPointsDone: 3, redeemedWant: 1, redeemedFun: 0)
        #expect(engine.availableWant == -1)
    }

    @Test func pointsToUnlockAccountsForSpentRewards() {
        let engine = RewardEngine(needPointsDone: 5, redeemedWant: 1, redeemedFun: 0)
        #expect(engine.pointsToUnlock(.want) == 3)  // needs 8 for a second Want
        #expect(engine.pointsToUnlock(.fun) == 2)
        #expect(RewardEngine(needPointsDone: 9, redeemedWant: 0, redeemedFun: 0).pointsToUnlock(.want) == 0)
        #expect(engine.lockedMessage(.want) == "Complete 3 more need points to earn a Want reward.")
    }

    @Test func customRatios() {
        let settings = RewardSettings(wantRatio: 3, funRatio: 10)
        let engine = RewardEngine(needPointsDone: 20, redeemedWant: 0, redeemedFun: 1, settings: settings)
        #expect(engine.availableWant == 6)
        #expect(engine.availableFun == 1)
        #expect(engine.fraction(.want) == 2.0 / 3.0)
    }

    @Test func ratiosAreClampedToAtLeastOne() {
        let settings = RewardSettings(wantRatio: 0, funRatio: -5)
        #expect(settings.wantRatio == 1)
        #expect(settings.funRatio == 1)
    }

    @Test func computesFromTicketsAndRedemptions() throws {
        let container = try ModelContainer(
            for: Ticket.self, Redemption.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let wantTicket = Ticket(title: "Movie", category: .want, points: 2)
        let tickets = [
            Ticket(title: "a", category: .need, points: 5, status: .done),
            Ticket(title: "b", category: .need, points: 3, status: .done),
            Ticket(title: "c", category: .need, points: 8, status: .inProgress), // not done
            Ticket(title: "d", category: .fun, points: 8, status: .done),        // not need
            wantTicket,
        ]
        tickets.forEach(context.insert)
        let redemptions = [Redemption(kind: .want, ticketID: wantTicket.id)]
        redemptions.forEach(context.insert)

        let engine = RewardEngine(tickets: tickets, redemptions: redemptions)
        #expect(engine.needPointsDone == 8)
        #expect(engine.availableWant == 1)
        #expect(engine.availableFun == 1)
        #expect(wantTicket.isLocked(redemptions: redemptions) == false)
        #expect(tickets[3].isLocked(redemptions: redemptions) == true)
        #expect(tickets[0].isLocked(redemptions: redemptions) == false)
    }

    /// SwiftUI observes settings via key-value observing, which can't see keys containing dots.
    @Test func categorySettingKeysAreObservable() {
        for category in Category.allCases {
            #expect(!category.colorKey.contains("."))
            #expect(!category.symbolKey.contains("."))
        }
        #expect(Category.need.colorKey == "categoryNeedColor")
    }

    @Test func statusKeepsCompletedAtInSync() {
        let ticket = Ticket(title: "x")
        #expect(ticket.completedAt == nil)
        ticket.status = .done
        #expect(ticket.completedAt != nil)
        ticket.status = .upNext
        #expect(ticket.completedAt == nil)
    }
}
