import XCTest

@testable import Runner

class TranscriptAccumulatorTests: XCTestCase {

  func testSingleSegmentUsesTheFinalText() {
    var transcript = TranscriptAccumulator()
    transcript.add("Start")
    transcript.add("Start with the chicken")
    transcript.add("Start with the chicken.")

    let (text, confidence) = transcript.finish(finalText: "Start with the chicken.")

    XCTAssertEqual(text, "Start with the chicken.")
    XCTAssertEqual(confidence, 1.0)
  }

  // The bug the pipeline harness found: the final result only held the last
  // segment ("Sauce last you're gonna mix that all up"), and earlier
  // segments were thrown away.
  func testKeepsEarlierSegmentsWhenTheFinalTextIsOnlyTheLastSegment() {
    var transcript = TranscriptAccumulator()
    transcript.add("Step one")
    transcript.add("Step one, take 2 lb chicken breast and ranch seasoning.")
    transcript.add("Grab")  // length drops: a new segment started
    transcript.add("Grab some beef bacon and chop 10 slices.")
    transcript.add("Sauce")  // another new segment
    transcript.add("Sauce last, you're gonna mix that all up.")

    let finalText = "Sauce last, you're gonna mix that all up."
    transcript.add(finalText)  // the bridge adds the final result too
    let (text, confidence) = transcript.finish(finalText: finalText)

    XCTAssertEqual(
      text,
      "Step one, take 2 lb chicken breast and ranch seasoning. "
        + "Grab some beef bacon and chop 10 slices. "
        + "Sauce last, you're gonna mix that all up."
    )
    XCTAssertEqual(confidence, 0.9)
  }

  func testEmptyFinalTextUsesTheSegments() {
    var transcript = TranscriptAccumulator()
    transcript.add("Add 500 g of cooked rice and 40 g of hot honey.")
    transcript.add("Mix")
    transcript.add("Mix it all up in five bowls.")
    transcript.add("")

    let (text, _) = transcript.finish(finalText: "")

    XCTAssertEqual(
      text, "Add 500 g of cooked rice and 40 g of hot honey. Mix it all up in five bowls.")
  }

  func testFinalTextCoveringEverythingIsPreferred() {
    var transcript = TranscriptAccumulator()
    transcript.add("Add 500 g of cooked rice and honey")
    transcript.add("Mix")
    transcript.add("Mix it all up")

    let whole = "Add 500 g of cooked rice and 40 g of hot honey. Mix it all up in five bowls."
    transcript.add(whole)
    let (text, confidence) = transcript.finish(finalText: whole)

    XCTAssertEqual(text, whole)
    XCTAssertEqual(confidence, 1.0)
  }

  func testSmallDropsInLengthDoNotStartANewSegment() {
    var transcript = TranscriptAccumulator()
    transcript.add("Mix the flour and sugar together")
    transcript.add("Mix the flour and sugar")  // revised, not a new segment

    XCTAssertTrue(transcript.completedSegments.isEmpty)
    XCTAssertEqual(transcript.text, "Mix the flour and sugar together")
  }
}
