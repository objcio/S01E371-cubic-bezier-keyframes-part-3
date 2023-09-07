//

import Foundation
import SwiftUI

protocol MyKeyframeTracks<Root> {
    associatedtype Root

    var duration: TimeInterval { get }

    func value(at time: TimeInterval, modify initial: inout Root)
}

protocol MyKeyframes<Value> {
    associatedtype Value

    var duration: TimeInterval { get }
    var to: Value { get }

    func interpolate(from: Value, time: TimeInterval) -> Value
}

struct MyKeyframeTimeline<Root> {
    var initialValue: Root
    var tracks: [any MyKeyframeTracks<Root>]

    var duration: TimeInterval {
        tracks.map { $0.duration }.max() ?? 0
    }

    func value(time: TimeInterval) -> Root {
        var result = initialValue
        for track in tracks {
            track.value(at: time, modify: &result)
        }
        return result
    }
}

struct MyKeyframeTrack<Root, Value: Animatable>: MyKeyframeTracks {
    var keyPath: WritableKeyPath<Root, Value>
    var keyframes: [any MyKeyframes<Value>]

    init(_ keyPath: WritableKeyPath<Root, Value>, _ keyframes: [any MyKeyframes<Value>]) {
        self.keyPath = keyPath
        self.keyframes = keyframes
    }

    var duration: TimeInterval {
        keyframes.reduce(0, { $0 + $1.duration })
    }

    func value(at time: TimeInterval, modify initial: inout Root) {
        initial[keyPath: keyPath] = value(at: time, initialValue: initial[keyPath: keyPath])
    }

    func value(at time: TimeInterval, initialValue: Value) -> Value {
        var currentTime: TimeInterval = 0
        var previousValue = initialValue
        for keyframe in keyframes {
            let relativeTime = time - currentTime
            defer { currentTime += keyframe.duration }
            guard relativeTime <= keyframe.duration else {
                previousValue = keyframe.to
                continue
            }

            return keyframe.interpolate(from: previousValue, time: relativeTime)
        }
        return keyframes.last?.to ?? initialValue
    }
}

struct MyLinearKeyframe<Value: Animatable>: MyKeyframes {
    var to: Value
    var duration: TimeInterval

    init(_ to: Value, duration: TimeInterval) {
        self.to = to
        self.duration = duration
    }

    func interpolate(from: Value, time: TimeInterval) -> Value {
        let progress = time/duration
        var result = from
        result.animatableData.interpolate(towards: to.animatableData, amount: progress)
        return result
    }
}

struct MyMoveKeyframe<Value: Animatable>: MyKeyframes {
    init(_ to: Value, duration: TimeInterval) {
        self.to = to
        self.duration = duration
    }
    var to: Value
    var duration: TimeInterval

    func interpolate(from: Value, time: TimeInterval) -> Value {
        to
    }
}

struct MyCubicKeyframe<Value: Animatable>: MyKeyframes {
    var to: Value
    var duration: TimeInterval
    var startVelocity: Value?
    var endVelocity: Value?

    init(_ to: Value, duration: TimeInterval, startVelocity: Value? = nil, endVelocity: Value? = nil) {
        self.to = to
        self.duration = duration
        self.startVelocity = startVelocity
        self.endVelocity = endVelocity
    }

    func interpolate(from: Value, time: TimeInterval) -> Value {
        let progress = time/duration
        let cp1 = AnimatablePair(1/3.0, from.animatableData + (startVelocity?.animatableData ?? .zero).scaled(by: duration/3))
        let cp2 = AnimatablePair(2/3.0, to.animatableData - (endVelocity?.animatableData ?? .zero).scaled(by: duration/3))
        let bezier = CubicBezier(p0: AnimatablePair(0, from.animatableData), p1: cp1, p2: cp2, p3: AnimatablePair(1, to.animatableData))
        var result = from
        let t = bezier.map { $0.first }.findT(time: progress)
        result.animatableData = bezier.value(for: t).second
        return result
    }
}
