@_exported import CBinaryen
import Foundation


/// Modules contain lists of functions, imports, exports, function types. The
/// add* methods create them on a module. The module owns them and will free their
/// memory when the module is disposed of.
///
/// Expressions are also allocated inside modules, and freed with the module. They
/// are not created by Add* methods, since they are not added directly on the
/// module, instead, they are arguments to other expressions (and then they are
/// the children of that AST node), or to a function (and then they are the body
/// of that function).
///
/// A module can also contain a function table for indirect calls, a memory,
/// and a start method.
///
public final class Module {

    public let moduleRef: BinaryenModuleRef!

    internal init(moduleRef: BinaryenModuleRef!) {
        self.moduleRef = moduleRef
    }

    public convenience init() {
        self.init(moduleRef: BinaryenModuleCreate())
    }

    // Deserialize a module from binary form.
    public convenience init(data: Data) {
        var data = data
        let count = data.count
        self.init(moduleRef: data.withUnsafeMutableBytes { pointer in
            BinaryenModuleRead(pointer, count)
        })
    }

    /// Validate a module, showing errors on problems.
    public var isValid: Bool {
        return BinaryenModuleValidate(moduleRef) == 1
    }

    /// Auto-generate drop() operations where needed. This lets you generate code without
    /// worrying about where they are needed. (It is more efficient to do it yourself,
    /// but simpler to use autodrop).
    public func autoDrop() {
        BinaryenModuleAutoDrop(moduleRef)
    }

    /// Runs the standard optimization passes on the module. Uses the currently set
    /// global optimize and shrink level.
    public func optimize() {
        BinaryenModuleOptimize(moduleRef)
    }

    /// Print a module to stdout in s-expression text format. Useful for debugging.
    public func print() {
        BinaryenModulePrint(moduleRef)
    }

    /// Serializes a module into binary form, optionally including its source map if
    /// sourceMapUrl has been specified. Uses the currently set global debugInfo option.
    public func write(sourceMapURL: String? = nil) -> WriteResult {
        return WriteResult(result:
            BinaryenModuleAllocateAndWrite(moduleRef, sourceMapURL?.cString(using: .utf8))
        )
    }

    /// Add a new function type. This is thread-safe.
    /// Note: name can be NULL, in which case we auto-generate a name
    public func addFunctionType(name: String? = nil, result: Type, parameterTypes: [Type]) -> FunctionType? {
        var parameterTypes = parameterTypes.map { $0.type }
        guard let functionTypeRef =
            BinaryenAddFunctionType(
                moduleRef,
                name?.cString(using: .utf8),
                result.type,
                UnsafeMutablePointer(&parameterTypes),
                BinaryenIndex(parameterTypes.count)
            )
        else {
            return nil
        }
        return FunctionType(functionTypeRef: functionTypeRef)
    }

    /// Removes a function type.
    public func removeFunctionType(name: String) {
        BinaryenRemoveFunctionType(moduleRef, name.cString(using: .utf8))
    }

    deinit {
        BinaryenModuleDispose(moduleRef)
    }
}


public struct FunctionType {

    public let functionTypeRef: BinaryenFunctionTypeRef!

    internal init(functionTypeRef: BinaryenFunctionTypeRef!) {
        self.functionTypeRef = functionTypeRef
    }

    /// Gets the name.
    public var name: String {
        return String(cString:
            BinaryenFunctionTypeGetName(functionTypeRef)
        )
    }

    /// Gets the result type.
    public var resultType: BinaryenType {
        return BinaryenFunctionTypeGetResult(functionTypeRef)
    }

    /// Gets the type of the parameter at the specified index.
    public func parameterType(at index: Int) -> BinaryenType? {
        return BinaryenFunctionTypeGetParam(functionTypeRef, BinaryenIndex(index))
    }

    /// Gets the number of parameters.
    public var parameterCount: Int {
        return Int(BinaryenFunctionTypeGetNumParams(functionTypeRef))
    }
}


public final class WriteResult {

    private let result: BinaryenModuleAllocateAndWriteResult

    public var data: Data {
        return Data(
            bytes: result.binary,
            count: result.binaryBytes
        )
    }

    internal init(result: BinaryenModuleAllocateAndWriteResult) {
        self.result = result
    }

    deinit {
        free(result.binary)
    }
}


public struct Binaryen {

    private init() {}

    /// The currently set optimize level. Applies to all modules, globally.
    /// 0, 1, 2 correspond to -O0, -O1, -O2 (default), etc.
    public static var optimizeLevel: Int {
        get {
            return Int(BinaryenGetOptimizeLevel())
        }
        set {
            BinaryenSetOptimizeLevel(Int32(newValue))
        }
    }

    /// The currently set shrink level. Applies to all modules, globally.
    /// 0, 1, 2 correspond to -O0, -Os (default), -Oz.
    public static var shrinkLevel: Int {
        get {
            return Int(BinaryenGetShrinkLevel())
        }
        set {
            BinaryenSetShrinkLevel(Int32(newValue))
        }
    }

    /// Enables or disables debug information in emitted binaries.
    /// Applies to all modules, globally.
    public static var isDebugInfoEnabled: Bool {
        get {
            return BinaryenGetDebugInfo() == 1
        }
        set {
            BinaryenSetDebugInfo(newValue ? 1 : 0)
        }
    }
}


/// Core types
public struct Type {

    public let type: BinaryenType

    internal init(type: BinaryenType) {
        self.type = type
    }

    public static let none = Type(type: BinaryenTypeNone())
    public static let int32 = Type(type: BinaryenTypeInt32())
    public static let int64 = Type(type: BinaryenTypeInt64())
    public static let float32 = Type(type: BinaryenTypeFloat32())
    public static let float64 = Type(type: BinaryenTypeFloat64())
    public static let vec128 = Type(type: BinaryenTypeVec128())
    public static let unreachable = Type(type: BinaryenTypeUnreachable())
    // Not a real type. Used as the last parameter to BinaryenBlock to let
    // the API figure out the type instead of providing one.
    public static let auto = Type(type: BinaryenTypeAuto())
}


/// Expression ids
public struct ExpressionId {

    public let expressionId: BinaryenExpressionId

    internal init(expressionId: BinaryenExpressionId) {
        self.expressionId = expressionId
    }

    public static let invalid = ExpressionId(expressionId: BinaryenInvalidId())
    public static let block = ExpressionId(expressionId: BinaryenBlockId())
    public static let `if` = ExpressionId(expressionId: BinaryenIfId())
    public static let loop = ExpressionId(expressionId: BinaryenLoopId())
    public static let `break` = ExpressionId(expressionId: BinaryenBreakId())
    public static let `switch` = ExpressionId(expressionId: BinaryenSwitchId())
    public static let call = ExpressionId(expressionId: BinaryenCallId())
    public static let callIndirect = ExpressionId(expressionId: BinaryenCallIndirectId())
    public static let getLocal = ExpressionId(expressionId: BinaryenGetLocalId())
    public static let setLocal = ExpressionId(expressionId: BinaryenSetLocalId())
    public static let getGlobal = ExpressionId(expressionId: BinaryenGetGlobalId())
    public static let setGlobal = ExpressionId(expressionId: BinaryenSetGlobalId())
    public static let load = ExpressionId(expressionId: BinaryenLoadId())
    public static let store = ExpressionId(expressionId: BinaryenStoreId())
    public static let const = ExpressionId(expressionId: BinaryenConstId())
    public static let unary = ExpressionId(expressionId: BinaryenUnaryId())
    public static let binary = ExpressionId(expressionId: BinaryenBinaryId())
    public static let select = ExpressionId(expressionId: BinaryenSelectId())
    public static let drop = ExpressionId(expressionId: BinaryenDropId())
    public static let `return` = ExpressionId(expressionId: BinaryenReturnId())
    public static let host = ExpressionId(expressionId: BinaryenHostId())
    public static let nop = ExpressionId(expressionId: BinaryenNopId())
    public static let unreachable = ExpressionId(expressionId: BinaryenUnreachableId())
    public static let atomicCmpxchg = ExpressionId(expressionId: BinaryenAtomicCmpxchgId())
    public static let atomicRMW = ExpressionId(expressionId: BinaryenAtomicRMWId())
    public static let atomicWait = ExpressionId(expressionId: BinaryenAtomicWaitId())
    public static let atomicNotify = ExpressionId(expressionId: BinaryenAtomicNotifyId())
    public static let sIMDExtract = ExpressionId(expressionId: BinaryenSIMDExtractId())
    public static let sIMDReplace = ExpressionId(expressionId: BinaryenSIMDReplaceId())
    public static let sIMDShuffle = ExpressionId(expressionId: BinaryenSIMDShuffleId())
    public static let sIMDBitselect = ExpressionId(expressionId: BinaryenSIMDBitselectId())
    public static let sIMDShift = ExpressionId(expressionId: BinaryenSIMDShiftId())
    public static let memoryInit = ExpressionId(expressionId: BinaryenMemoryInitId())
    public static let dataDrop = ExpressionId(expressionId: BinaryenDataDropId())
    public static let memoryCopy = ExpressionId(expressionId: BinaryenMemoryCopyId())
    public static let memoryFill = ExpressionId(expressionId: BinaryenMemoryFillId())
}


/// External kinds
public struct ExternalKind {

    public let expressionId: BinaryenExpressionId

    internal init(expressionId: BinaryenExpressionId) {
        self.expressionId = expressionId
    }

    public static let function = ExternalKind(expressionId: BinaryenExternalFunction())
    public static let table = ExternalKind(expressionId: BinaryenExternalTable())
    public static let memory = ExternalKind(expressionId: BinaryenExternalMemory())
    public static let global = ExternalKind(expressionId: BinaryenExternalGlobal())
}


public extension BinaryenLiteral {

    static func int32(_ value: Int32) -> BinaryenLiteral {
        return BinaryenLiteralInt32(value)
    }

    static func int64(_ value: Int64) -> BinaryenLiteral {
        return BinaryenLiteralInt64(value)
    }

    static func float32(_ value: Float) -> BinaryenLiteral {
        return BinaryenLiteralFloat32(value)
    }

    static func float64(_ value: Double) -> BinaryenLiteral {
        return BinaryenLiteralFloat64(value)
    }

    static func vec128(_ value: [UInt8]) -> BinaryenLiteral {
        return BinaryenLiteralVec128(UnsafePointer(value))
    }

    static func float32Bits(_ value: Int32) -> BinaryenLiteral {
        return BinaryenLiteralFloat32Bits(value)
    }

    static func float64Bits(_ value: Int64) -> BinaryenLiteral {
        return BinaryenLiteralFloat64Bits(value)
    }
}


public typealias Literal = BinaryenLiteral



public struct Op {

    public let op: BinaryenOp

    internal init(op: BinaryenOp) {
        self.op = op
    }

    public static let clzInt32 = Op(op: BinaryenClzInt32())
    public static let ctzInt32 = Op(op: BinaryenCtzInt32())
    public static let popcntInt32 = Op(op: BinaryenPopcntInt32())
    public static let negFloat32 = Op(op: BinaryenNegFloat32())
    public static let absFloat32 = Op(op: BinaryenAbsFloat32())
    public static let ceilFloat32 = Op(op: BinaryenCeilFloat32())
    public static let floorFloat32 = Op(op: BinaryenFloorFloat32())
    public static let truncFloat32 = Op(op: BinaryenTruncFloat32())
    public static let nearestFloat32 = Op(op: BinaryenNearestFloat32())
    public static let sqrtFloat32 = Op(op: BinaryenSqrtFloat32())
    public static let eqZInt32 = Op(op: BinaryenEqZInt32())
    public static let clzInt64 = Op(op: BinaryenClzInt64())
    public static let ctzInt64 = Op(op: BinaryenCtzInt64())
    public static let popcntInt64 = Op(op: BinaryenPopcntInt64())
    public static let negFloat64 = Op(op: BinaryenNegFloat64())
    public static let absFloat64 = Op(op: BinaryenAbsFloat64())
    public static let ceilFloat64 = Op(op: BinaryenCeilFloat64())
    public static let floorFloat64 = Op(op: BinaryenFloorFloat64())
    public static let truncFloat64 = Op(op: BinaryenTruncFloat64())
    public static let nearestFloat64 = Op(op: BinaryenNearestFloat64())
    public static let sqrtFloat64 = Op(op: BinaryenSqrtFloat64())
    public static let eqZInt64 = Op(op: BinaryenEqZInt64())
    public static let extendSInt32 = Op(op: BinaryenExtendSInt32())
    public static let extendUInt32 = Op(op: BinaryenExtendUInt32())
    public static let wrapInt64 = Op(op: BinaryenWrapInt64())
    public static let truncSFloat32ToInt32 = Op(op: BinaryenTruncSFloat32ToInt32())
    public static let truncSFloat32ToInt64 = Op(op: BinaryenTruncSFloat32ToInt64())
    public static let truncUFloat32ToInt32 = Op(op: BinaryenTruncUFloat32ToInt32())
    public static let truncUFloat32ToInt64 = Op(op: BinaryenTruncUFloat32ToInt64())
    public static let truncSFloat64ToInt32 = Op(op: BinaryenTruncSFloat64ToInt32())
    public static let truncSFloat64ToInt64 = Op(op: BinaryenTruncSFloat64ToInt64())
    public static let truncUFloat64ToInt32 = Op(op: BinaryenTruncUFloat64ToInt32())
    public static let truncUFloat64ToInt64 = Op(op: BinaryenTruncUFloat64ToInt64())
    public static let reinterpretFloat32 = Op(op: BinaryenReinterpretFloat32())
    public static let reinterpretFloat64 = Op(op: BinaryenReinterpretFloat64())
    public static let convertSInt32ToFloat32 = Op(op: BinaryenConvertSInt32ToFloat32())
    public static let convertSInt32ToFloat64 = Op(op: BinaryenConvertSInt32ToFloat64())
    public static let convertUInt32ToFloat32 = Op(op: BinaryenConvertUInt32ToFloat32())
    public static let convertUInt32ToFloat64 = Op(op: BinaryenConvertUInt32ToFloat64())
    public static let convertSInt64ToFloat32 = Op(op: BinaryenConvertSInt64ToFloat32())
    public static let convertSInt64ToFloat64 = Op(op: BinaryenConvertSInt64ToFloat64())
    public static let convertUInt64ToFloat32 = Op(op: BinaryenConvertUInt64ToFloat32())
    public static let convertUInt64ToFloat64 = Op(op: BinaryenConvertUInt64ToFloat64())
    public static let promoteFloat32 = Op(op: BinaryenPromoteFloat32())
    public static let demoteFloat64 = Op(op: BinaryenDemoteFloat64())
    public static let reinterpretInt32 = Op(op: BinaryenReinterpretInt32())
    public static let reinterpretInt64 = Op(op: BinaryenReinterpretInt64())
    public static let extendS8Int32 = Op(op: BinaryenExtendS8Int32())
    public static let extendS16Int32 = Op(op: BinaryenExtendS16Int32())
    public static let extendS8Int64 = Op(op: BinaryenExtendS8Int64())
    public static let extendS16Int64 = Op(op: BinaryenExtendS16Int64())
    public static let extendS32Int64 = Op(op: BinaryenExtendS32Int64())
    public static let addInt32 = Op(op: BinaryenAddInt32())
    public static let subInt32 = Op(op: BinaryenSubInt32())
    public static let mulInt32 = Op(op: BinaryenMulInt32())
    public static let divSInt32 = Op(op: BinaryenDivSInt32())
    public static let divUInt32 = Op(op: BinaryenDivUInt32())
    public static let remSInt32 = Op(op: BinaryenRemSInt32())
    public static let remUInt32 = Op(op: BinaryenRemUInt32())
    public static let andInt32 = Op(op: BinaryenAndInt32())
    public static let orInt32 = Op(op: BinaryenOrInt32())
    public static let xorInt32 = Op(op: BinaryenXorInt32())
    public static let shlInt32 = Op(op: BinaryenShlInt32())
    public static let shrUInt32 = Op(op: BinaryenShrUInt32())
    public static let shrSInt32 = Op(op: BinaryenShrSInt32())
    public static let rotLInt32 = Op(op: BinaryenRotLInt32())
    public static let rotRInt32 = Op(op: BinaryenRotRInt32())
    public static let eqInt32 = Op(op: BinaryenEqInt32())
    public static let neInt32 = Op(op: BinaryenNeInt32())
    public static let ltSInt32 = Op(op: BinaryenLtSInt32())
    public static let ltUInt32 = Op(op: BinaryenLtUInt32())
    public static let leSInt32 = Op(op: BinaryenLeSInt32())
    public static let leUInt32 = Op(op: BinaryenLeUInt32())
    public static let gtSInt32 = Op(op: BinaryenGtSInt32())
    public static let gtUInt32 = Op(op: BinaryenGtUInt32())
    public static let geSInt32 = Op(op: BinaryenGeSInt32())
    public static let geUInt32 = Op(op: BinaryenGeUInt32())
    public static let addInt64 = Op(op: BinaryenAddInt64())
    public static let subInt64 = Op(op: BinaryenSubInt64())
    public static let mulInt64 = Op(op: BinaryenMulInt64())
    public static let divSInt64 = Op(op: BinaryenDivSInt64())
    public static let divUInt64 = Op(op: BinaryenDivUInt64())
    public static let remSInt64 = Op(op: BinaryenRemSInt64())
    public static let remUInt64 = Op(op: BinaryenRemUInt64())
    public static let andInt64 = Op(op: BinaryenAndInt64())
    public static let orInt64 = Op(op: BinaryenOrInt64())
    public static let xorInt64 = Op(op: BinaryenXorInt64())
    public static let shlInt64 = Op(op: BinaryenShlInt64())
    public static let shrUInt64 = Op(op: BinaryenShrUInt64())
    public static let shrSInt64 = Op(op: BinaryenShrSInt64())
    public static let rotLInt64 = Op(op: BinaryenRotLInt64())
    public static let rotRInt64 = Op(op: BinaryenRotRInt64())
    public static let eqInt64 = Op(op: BinaryenEqInt64())
    public static let neInt64 = Op(op: BinaryenNeInt64())
    public static let ltSInt64 = Op(op: BinaryenLtSInt64())
    public static let ltUInt64 = Op(op: BinaryenLtUInt64())
    public static let leSInt64 = Op(op: BinaryenLeSInt64())
    public static let leUInt64 = Op(op: BinaryenLeUInt64())
    public static let gtSInt64 = Op(op: BinaryenGtSInt64())
    public static let gtUInt64 = Op(op: BinaryenGtUInt64())
    public static let geSInt64 = Op(op: BinaryenGeSInt64())
    public static let geUInt64 = Op(op: BinaryenGeUInt64())
    public static let addFloat32 = Op(op: BinaryenAddFloat32())
    public static let subFloat32 = Op(op: BinaryenSubFloat32())
    public static let mulFloat32 = Op(op: BinaryenMulFloat32())
    public static let divFloat32 = Op(op: BinaryenDivFloat32())
    public static let copySignFloat32 = Op(op: BinaryenCopySignFloat32())
    public static let minFloat32 = Op(op: BinaryenMinFloat32())
    public static let maxFloat32 = Op(op: BinaryenMaxFloat32())
    public static let eqFloat32 = Op(op: BinaryenEqFloat32())
    public static let neFloat32 = Op(op: BinaryenNeFloat32())
    public static let ltFloat32 = Op(op: BinaryenLtFloat32())
    public static let leFloat32 = Op(op: BinaryenLeFloat32())
    public static let gtFloat32 = Op(op: BinaryenGtFloat32())
    public static let geFloat32 = Op(op: BinaryenGeFloat32())
    public static let addFloat64 = Op(op: BinaryenAddFloat64())
    public static let subFloat64 = Op(op: BinaryenSubFloat64())
    public static let mulFloat64 = Op(op: BinaryenMulFloat64())
    public static let divFloat64 = Op(op: BinaryenDivFloat64())
    public static let copySignFloat64 = Op(op: BinaryenCopySignFloat64())
    public static let minFloat64 = Op(op: BinaryenMinFloat64())
    public static let maxFloat64 = Op(op: BinaryenMaxFloat64())
    public static let eqFloat64 = Op(op: BinaryenEqFloat64())
    public static let neFloat64 = Op(op: BinaryenNeFloat64())
    public static let ltFloat64 = Op(op: BinaryenLtFloat64())
    public static let leFloat64 = Op(op: BinaryenLeFloat64())
    public static let gtFloat64 = Op(op: BinaryenGtFloat64())
    public static let geFloat64 = Op(op: BinaryenGeFloat64())
    public static let currentMemory = Op(op: BinaryenCurrentMemory())
    public static let growMemory = Op(op: BinaryenGrowMemory())
    public static let atomicRMWAdd = Op(op: BinaryenAtomicRMWAdd())
    public static let atomicRMWSub = Op(op: BinaryenAtomicRMWSub())
    public static let atomicRMWAnd = Op(op: BinaryenAtomicRMWAnd())
    public static let atomicRMWOr = Op(op: BinaryenAtomicRMWOr())
    public static let atomicRMWXor = Op(op: BinaryenAtomicRMWXor())
    public static let atomicRMWXchg = Op(op: BinaryenAtomicRMWXchg())
    public static let truncSatSFloat32ToInt32 = Op(op: BinaryenTruncSatSFloat32ToInt32())
    public static let truncSatSFloat32ToInt64 = Op(op: BinaryenTruncSatSFloat32ToInt64())
    public static let truncSatUFloat32ToInt32 = Op(op: BinaryenTruncSatUFloat32ToInt32())
    public static let truncSatUFloat32ToInt64 = Op(op: BinaryenTruncSatUFloat32ToInt64())
    public static let truncSatSFloat64ToInt32 = Op(op: BinaryenTruncSatSFloat64ToInt32())
    public static let truncSatSFloat64ToInt64 = Op(op: BinaryenTruncSatSFloat64ToInt64())
    public static let truncSatUFloat64ToInt32 = Op(op: BinaryenTruncSatUFloat64ToInt32())
    public static let truncSatUFloat64ToInt64 = Op(op: BinaryenTruncSatUFloat64ToInt64())
    public static let splatVecI8x16 = Op(op: BinaryenSplatVecI8x16())
    public static let extractLaneSVecI8x16 = Op(op: BinaryenExtractLaneSVecI8x16())
    public static let extractLaneUVecI8x16 = Op(op: BinaryenExtractLaneUVecI8x16())
    public static let replaceLaneVecI8x16 = Op(op: BinaryenReplaceLaneVecI8x16())
    public static let splatVecI16x8 = Op(op: BinaryenSplatVecI16x8())
    public static let extractLaneSVecI16x8 = Op(op: BinaryenExtractLaneSVecI16x8())
    public static let extractLaneUVecI16x8 = Op(op: BinaryenExtractLaneUVecI16x8())
    public static let replaceLaneVecI16x8 = Op(op: BinaryenReplaceLaneVecI16x8())
    public static let splatVecI32x4 = Op(op: BinaryenSplatVecI32x4())
    public static let extractLaneVecI32x4 = Op(op: BinaryenExtractLaneVecI32x4())
    public static let replaceLaneVecI32x4 = Op(op: BinaryenReplaceLaneVecI32x4())
    public static let splatVecI64x2 = Op(op: BinaryenSplatVecI64x2())
    public static let extractLaneVecI64x2 = Op(op: BinaryenExtractLaneVecI64x2())
    public static let replaceLaneVecI64x2 = Op(op: BinaryenReplaceLaneVecI64x2())
    public static let splatVecF32x4 = Op(op: BinaryenSplatVecF32x4())
    public static let extractLaneVecF32x4 = Op(op: BinaryenExtractLaneVecF32x4())
    public static let replaceLaneVecF32x4 = Op(op: BinaryenReplaceLaneVecF32x4())
    public static let splatVecF64x2 = Op(op: BinaryenSplatVecF64x2())
    public static let extractLaneVecF64x2 = Op(op: BinaryenExtractLaneVecF64x2())
    public static let replaceLaneVecF64x2 = Op(op: BinaryenReplaceLaneVecF64x2())
    public static let eqVecI8x16 = Op(op: BinaryenEqVecI8x16())
    public static let neVecI8x16 = Op(op: BinaryenNeVecI8x16())
    public static let ltSVecI8x16 = Op(op: BinaryenLtSVecI8x16())
    public static let ltUVecI8x16 = Op(op: BinaryenLtUVecI8x16())
    public static let gtSVecI8x16 = Op(op: BinaryenGtSVecI8x16())
    public static let gtUVecI8x16 = Op(op: BinaryenGtUVecI8x16())
    public static let leSVecI8x16 = Op(op: BinaryenLeSVecI8x16())
    public static let leUVecI8x16 = Op(op: BinaryenLeUVecI8x16())
    public static let geSVecI8x16 = Op(op: BinaryenGeSVecI8x16())
    public static let geUVecI8x16 = Op(op: BinaryenGeUVecI8x16())
    public static let eqVecI16x8 = Op(op: BinaryenEqVecI16x8())
    public static let neVecI16x8 = Op(op: BinaryenNeVecI16x8())
    public static let ltSVecI16x8 = Op(op: BinaryenLtSVecI16x8())
    public static let ltUVecI16x8 = Op(op: BinaryenLtUVecI16x8())
    public static let gtSVecI16x8 = Op(op: BinaryenGtSVecI16x8())
    public static let gtUVecI16x8 = Op(op: BinaryenGtUVecI16x8())
    public static let leSVecI16x8 = Op(op: BinaryenLeSVecI16x8())
    public static let leUVecI16x8 = Op(op: BinaryenLeUVecI16x8())
    public static let geSVecI16x8 = Op(op: BinaryenGeSVecI16x8())
    public static let geUVecI16x8 = Op(op: BinaryenGeUVecI16x8())
    public static let eqVecI32x4 = Op(op: BinaryenEqVecI32x4())
    public static let neVecI32x4 = Op(op: BinaryenNeVecI32x4())
    public static let ltSVecI32x4 = Op(op: BinaryenLtSVecI32x4())
    public static let ltUVecI32x4 = Op(op: BinaryenLtUVecI32x4())
    public static let gtSVecI32x4 = Op(op: BinaryenGtSVecI32x4())
    public static let gtUVecI32x4 = Op(op: BinaryenGtUVecI32x4())
    public static let leSVecI32x4 = Op(op: BinaryenLeSVecI32x4())
    public static let leUVecI32x4 = Op(op: BinaryenLeUVecI32x4())
    public static let geSVecI32x4 = Op(op: BinaryenGeSVecI32x4())
    public static let geUVecI32x4 = Op(op: BinaryenGeUVecI32x4())
    public static let eqVecF32x4 = Op(op: BinaryenEqVecF32x4())
    public static let neVecF32x4 = Op(op: BinaryenNeVecF32x4())
    public static let ltVecF32x4 = Op(op: BinaryenLtVecF32x4())
    public static let gtVecF32x4 = Op(op: BinaryenGtVecF32x4())
    public static let leVecF32x4 = Op(op: BinaryenLeVecF32x4())
    public static let geVecF32x4 = Op(op: BinaryenGeVecF32x4())
    public static let eqVecF64x2 = Op(op: BinaryenEqVecF64x2())
    public static let neVecF64x2 = Op(op: BinaryenNeVecF64x2())
    public static let ltVecF64x2 = Op(op: BinaryenLtVecF64x2())
    public static let gtVecF64x2 = Op(op: BinaryenGtVecF64x2())
    public static let leVecF64x2 = Op(op: BinaryenLeVecF64x2())
    public static let geVecF64x2 = Op(op: BinaryenGeVecF64x2())
    public static let notVec128 = Op(op: BinaryenNotVec128())
    public static let andVec128 = Op(op: BinaryenAndVec128())
    public static let orVec128 = Op(op: BinaryenOrVec128())
    public static let xorVec128 = Op(op: BinaryenXorVec128())
    public static let negVecI8x16 = Op(op: BinaryenNegVecI8x16())
    public static let anyTrueVecI8x16 = Op(op: BinaryenAnyTrueVecI8x16())
    public static let allTrueVecI8x16 = Op(op: BinaryenAllTrueVecI8x16())
    public static let shlVecI8x16 = Op(op: BinaryenShlVecI8x16())
    public static let shrSVecI8x16 = Op(op: BinaryenShrSVecI8x16())
    public static let shrUVecI8x16 = Op(op: BinaryenShrUVecI8x16())
    public static let addVecI8x16 = Op(op: BinaryenAddVecI8x16())
    public static let addSatSVecI8x16 = Op(op: BinaryenAddSatSVecI8x16())
    public static let addSatUVecI8x16 = Op(op: BinaryenAddSatUVecI8x16())
    public static let subVecI8x16 = Op(op: BinaryenSubVecI8x16())
    public static let subSatSVecI8x16 = Op(op: BinaryenSubSatSVecI8x16())
    public static let subSatUVecI8x16 = Op(op: BinaryenSubSatUVecI8x16())
    public static let mulVecI8x16 = Op(op: BinaryenMulVecI8x16())
    public static let negVecI16x8 = Op(op: BinaryenNegVecI16x8())
    public static let anyTrueVecI16x8 = Op(op: BinaryenAnyTrueVecI16x8())
    public static let allTrueVecI16x8 = Op(op: BinaryenAllTrueVecI16x8())
    public static let shlVecI16x8 = Op(op: BinaryenShlVecI16x8())
    public static let shrSVecI16x8 = Op(op: BinaryenShrSVecI16x8())
    public static let shrUVecI16x8 = Op(op: BinaryenShrUVecI16x8())
    public static let addVecI16x8 = Op(op: BinaryenAddVecI16x8())
    public static let addSatSVecI16x8 = Op(op: BinaryenAddSatSVecI16x8())
    public static let addSatUVecI16x8 = Op(op: BinaryenAddSatUVecI16x8())
    public static let subVecI16x8 = Op(op: BinaryenSubVecI16x8())
    public static let subSatSVecI16x8 = Op(op: BinaryenSubSatSVecI16x8())
    public static let subSatUVecI16x8 = Op(op: BinaryenSubSatUVecI16x8())
    public static let mulVecI16x8 = Op(op: BinaryenMulVecI16x8())
    public static let negVecI32x4 = Op(op: BinaryenNegVecI32x4())
    public static let anyTrueVecI32x4 = Op(op: BinaryenAnyTrueVecI32x4())
    public static let allTrueVecI32x4 = Op(op: BinaryenAllTrueVecI32x4())
    public static let shlVecI32x4 = Op(op: BinaryenShlVecI32x4())
    public static let shrSVecI32x4 = Op(op: BinaryenShrSVecI32x4())
    public static let shrUVecI32x4 = Op(op: BinaryenShrUVecI32x4())
    public static let addVecI32x4 = Op(op: BinaryenAddVecI32x4())
    public static let subVecI32x4 = Op(op: BinaryenSubVecI32x4())
    public static let mulVecI32x4 = Op(op: BinaryenMulVecI32x4())
    public static let negVecI64x2 = Op(op: BinaryenNegVecI64x2())
    public static let anyTrueVecI64x2 = Op(op: BinaryenAnyTrueVecI64x2())
    public static let allTrueVecI64x2 = Op(op: BinaryenAllTrueVecI64x2())
    public static let shlVecI64x2 = Op(op: BinaryenShlVecI64x2())
    public static let shrSVecI64x2 = Op(op: BinaryenShrSVecI64x2())
    public static let shrUVecI64x2 = Op(op: BinaryenShrUVecI64x2())
    public static let addVecI64x2 = Op(op: BinaryenAddVecI64x2())
    public static let subVecI64x2 = Op(op: BinaryenSubVecI64x2())
    public static let absVecF32x4 = Op(op: BinaryenAbsVecF32x4())
    public static let negVecF32x4 = Op(op: BinaryenNegVecF32x4())
    public static let sqrtVecF32x4 = Op(op: BinaryenSqrtVecF32x4())
    public static let addVecF32x4 = Op(op: BinaryenAddVecF32x4())
    public static let subVecF32x4 = Op(op: BinaryenSubVecF32x4())
    public static let mulVecF32x4 = Op(op: BinaryenMulVecF32x4())
    public static let divVecF32x4 = Op(op: BinaryenDivVecF32x4())
    public static let minVecF32x4 = Op(op: BinaryenMinVecF32x4())
    public static let maxVecF32x4 = Op(op: BinaryenMaxVecF32x4())
    public static let absVecF64x2 = Op(op: BinaryenAbsVecF64x2())
    public static let negVecF64x2 = Op(op: BinaryenNegVecF64x2())
    public static let sqrtVecF64x2 = Op(op: BinaryenSqrtVecF64x2())
    public static let addVecF64x2 = Op(op: BinaryenAddVecF64x2())
    public static let subVecF64x2 = Op(op: BinaryenSubVecF64x2())
    public static let mulVecF64x2 = Op(op: BinaryenMulVecF64x2())
    public static let divVecF64x2 = Op(op: BinaryenDivVecF64x2())
    public static let minVecF64x2 = Op(op: BinaryenMinVecF64x2())
    public static let maxVecF64x2 = Op(op: BinaryenMaxVecF64x2())
    public static let truncSatSVecF32x4ToVecI32x4 = Op(op: BinaryenTruncSatSVecF32x4ToVecI32x4())
    public static let truncSatUVecF32x4ToVecI32x4 = Op(op: BinaryenTruncSatUVecF32x4ToVecI32x4())
    public static let truncSatSVecF64x2ToVecI64x2 = Op(op: BinaryenTruncSatSVecF64x2ToVecI64x2())
    public static let truncSatUVecF64x2ToVecI64x2 = Op(op: BinaryenTruncSatUVecF64x2ToVecI64x2())
    public static let convertSVecI32x4ToVecF32x4 = Op(op: BinaryenConvertSVecI32x4ToVecF32x4())
    public static let convertUVecI32x4ToVecF32x4 = Op(op: BinaryenConvertUVecI32x4ToVecF32x4())
    public static let convertSVecI64x2ToVecF64x2 = Op(op: BinaryenConvertSVecI64x2ToVecF64x2())
    public static let convertUVecI64x2ToVecF64x2 = Op(op: BinaryenConvertUVecI64x2ToVecF64x2())
}


public class Expression {
    public let expressionRef: BinaryenExpressionRef!

    internal init(expressionRef: BinaryenExpressionRef!) {
        self.expressionRef = expressionRef
    }

    public var expressionId: ExpressionId {
        return ExpressionId(expressionId: BinaryenExpressionGetId(expressionRef))
    }

    public var type: Type {
        return Type(type: BinaryenExpressionGetType(expressionRef))
    }

    public func print() {
        BinaryenExpressionPrint(expressionRef)
    }

    // Block: `name` can be nil. Specifying `Type.auto` as the 'type'
    //        parameter indicates that the block's type shall be figured out
    //        automatically instead of explicitly providing it. This conforms
    //        to the behavior before the 'type' parameter has been introduced.
    public static func block(
        module: Module,
        name: String? = nil,
        children: [Expression],
        type: Type
    )
        -> Expression
    {
        var children = children.map { $0.expressionRef }
        return BlockExpression(
            expressionRef: BinaryenBlock(
                module.moduleRef,
                name?.cString(using: .utf8),
                UnsafeMutablePointer(&children),
                BinaryenIndex(children.count),
                type.type
            )
        )
    }

    // If: ifFalse can be nil
    public static func `if`(
        module: Module,
        condition: Expression,
        ifTrue: Expression,
        ifFalse: Expression?
    )
        -> Expression
    {
        return IfExpression(
            expressionRef: BinaryenIf(
                module.moduleRef,
                condition.expressionRef,
                ifTrue.expressionRef,
                ifFalse?.expressionRef
            )
        )
    }

    // TODO: add more

}


public final class BlockExpression: Expression {

    public var name: String {
        return String(cString: BinaryenBlockGetName(expressionRef))
    }

    public var childCount: Int {
        return Int(BinaryenBlockGetNumChildren(expressionRef))
    }

    public func child(at index: Int) -> Expression? {
        return BinaryenBlockGetChild(expressionRef, BinaryenIndex(index))
            .map { Expression(expressionRef: $0) }
    }
}


public final class IfExpression: Expression {

    public var condition: Expression {
        return Expression(expressionRef: BinaryenIfGetCondition(expressionRef))
    }

    public var ifTrue: Expression {
        return Expression(expressionRef: BinaryenIfGetIfTrue(expressionRef))
    }

    public var ifFalse: Expression? {
        return BinaryenIfGetIfFalse(expressionRef)
            .map { Expression(expressionRef: $0) }
    }
}
