/// Provides a safe wrapper for any SV, which can contain any Perl value,
/// not only scalars. Performs reference counting on initialization and
/// deinitialization.
open class PerlValue : AnyPerl, CustomDebugStringConvertible {
	let unsafeSvContext: UnsafeSvContext

	/// Unsafely creates an instance without incrementing a reference counter of a SV.
	/// Performs no type checks and should be used only if compatibility is known.
	public required init(noincUnchecked svc: UnsafeSvContext) {
		unsafeSvContext = svc
	}

	/// Unsafely creates an instance incrementing a reference counter of a SV.
	/// Performs no type checks and should be used only if compatibility is known.
	public required init(incUnchecked svc: UnsafeSvContext) {
		svc.refcntInc()
		unsafeSvContext = svc
	}

	/// Unsafely creates an instance without incrementing a reference counter of a SV.
	/// Performs type checks and throws an error unless compatible.
	public convenience init(noinc svc: UnsafeSvContext) throws {
		self.init(noincUnchecked: svc)
	}

	/// Unsafely creates an instance incrementing a reference counter of a SV.
	/// Performs type checks and throws an error unless compatible.
	public convenience init(inc svc: UnsafeSvContext) throws {
		svc.refcntInc()
		try self.init(noinc: svc)
	}

	deinit {
		unsafeSvContext.refcntDec()
	}

	/// Invokes the given closure on the unsafe context containing pointers
	/// to the SV and the Perl interpreter.
	///
	/// The `withUnsafeSvContext(_:)` method ensures that the SV's
	/// lifetime extends through the execution of `body`.
	///
	/// - Parameter body: A closure that takes `UnsafeSvContext` as its argument.
	///   If the closure has a return value, it is used as the
	///   return value of the `withUnsafeSvContext(_:)` method.
	/// - Returns: The return value of the `body` closure, if any.
	public final func withUnsafeSvContext<R>(_ body: (UnsafeSvContext) throws -> R) rethrows -> R {
		defer { _fixLifetime(self) }
		return try body(unsafeSvContext)
	}

	var type: SvType {
		defer { _fixLifetime(self) }
		return unsafeSvContext.type
	}

	static func derivedClass(for svc: UnsafeSvContext) -> PerlValue.Type {
		switch svc.type {
			case .scalar:
				if let classname = svc.classname {
					return PerlObject.derivedClass(for: classname)
				} else {
					return PerlScalar.self
				}
			case .array: return PerlArray.self
			case .hash: return PerlHash.self
			case .code: return PerlSub.self
			default: return PerlValue.self
		}
	}

	static func initDerived(noinc svc: UnsafeSvContext) -> PerlValue {
		let subclass = derivedClass(for: svc)
		return subclass.init(noincUnchecked: svc)
	}

	static func initDerived(inc svc: UnsafeSvContext) -> PerlValue {
		let subclass = derivedClass(for: svc)
		return subclass.init(incUnchecked: svc)
	}

	/// Dumps the contents of the underlying SV to the "STDERR" filehandle.
	public func dump() {
		withUnsafeSvContext { $0.dump() }
	}

	/// A textual representation of the SV, suitable for debugging.
	public var debugDescription: String {
		return "PerlValue(\(type))"
	}
}
