module ApproxFunOrthogonalPolynomials
using Base, LinearAlgebra, Reexport, BandedMatrices, BlockBandedMatrices,
            BlockArrays, FillArrays, FastTransforms, IntervalSets,
            DomainSets, Statistics, SpecialFunctions, FastGaussQuadrature

@reexport using ApproxFunBase

import ApproxFunBase: Fun, SubSpace, WeightSpace, NoSpace, HeavisideSpace,
                    IntervalOrSegment, AnyDomain, ArraySpace,
                    AbstractTransformPlan, TransformPlan, ITransformPlan,
                    ConcreteConversion, ConcreteMultiplication, ConcreteDerivative,
                    ConcreteDefiniteIntegral, ConcreteDefiniteLineIntegral,
                    ConcreteVolterra, Volterra, Evaluation, EvaluationWrapper,
                    MultiplicationWrapper, ConversionWrapper, DerivativeWrapper,
                    Conversion, defaultcoefficients, default_Fun, Multiplication,
                    Derivative, bandwidths, ConcreteEvaluation, ConcreteIntegral,
                    DefiniteLineIntegral, DefiniteIntegral, IntegralWrapper,
                    ReverseOrientation, ReverseOrientationWrapper, ReverseWrapper,
                    Reverse, NegateEven, Dirichlet, ConcreteDirichlet,
                    TridiagonalOperator, SubOperator, Space, @containsconstants, spacescompatible,
                    canonicalspace, domain, setdomain, prectype, domainscompatible,
                    plan_transform, plan_itransform, plan_transform!, plan_itransform!,
                    transform, itransform, hasfasttransform,
                    CanonicalTransformPlan, ICanonicalTransformPlan,
                    Integral, domainspace, rangespace, boundary,
                    maxspace, hasconversion, points,
                    union_rule, conversion_rule, maxspace_rule, conversion_type,
                    linesum, differentiate, integrate, linebilinearform, bilinearform,
                    Segment, IntervalOrSegmentDomain, PiecewiseSegment, isambiguous,
                    eps, isperiodic, arclength, complexlength,
                    invfromcanonicalD, fromcanonical, tocanonical, fromcanonicalD,
                    tocanonicalD, canonicaldomain, setcanonicaldomain, mappoint,
                    reverseorientation, checkpoints, evaluate, extrapolate, mul_coefficients,
                    coefficients, isconvertible, clenshaw, ClenshawPlan,
                    toeplitz_axpy!, sym_toeplitz_axpy!, hankel_axpy!,
                    ToeplitzOperator, SymToeplitzOperator, SpaceOperator, cfstype,
                    alternatesign!, mobius, chebmult_getindex, intpow, alternatingsum,
                    extremal_args, chebyshev_clenshaw, recA, recB, recC, roots,
                    diagindshift, rangetype, weight, isapproxinteger, default_Dirichlet, scal!,
                    components, promoterangespace,
                    block, blockstart, blockstop, blocklengths, isblockbanded,
                    pointscompatible, affine_setdiff, complexroots,
                    ℓ⁰, recα, recβ, recγ, ℵ₀, ∞, RectDomain

import DomainSets: Domain, indomain, UnionDomain, FullSpace, Point,
            Interval, ChebyshevInterval, boundary, rightendpoint, leftendpoint,
            dimension, WrappedDomain

import BandedMatrices: bandshift, bandwidth, colstop, bandwidths, BandedMatrix

import Base: convert, getindex, *, +, -, ==, <, <=, >, |, !, !=, eltype,
                >=, /, ^, \, ∪, transpose, size, copyto!, copy,
                map, vcat, hcat, show, stride, sum, cumsum, conj, inv,
                complex, reverse, exp, sqrt, abs, sign, issubset, values,
                first, last, rand, intersect, setdiff,
                isless, union, angle, isnan, isapprox, isempty, sort, merge,
                minimum, maximum, extrema, argmax, argmin,
                zeros, zero, one, promote_rule, length, resize!, isinf,
                getproperty, cld, div, real, imag,
                max, min, log, acosh, tanh, atanh,
                atan, sinh, asinh,
                tan, tanh, asin, sec, acos,
                sin, cos, sinh, cosh,
                asinh, acosh, atanh,
                Array, Vector, Matrix, view, ones, split

import LinearAlgebra: norm, mul!, det, eigvals, qr, Tridiagonal, transpose

import FastTransforms: plan_chebyshevtransform, plan_chebyshevtransform!,
                        plan_ichebyshevtransform, plan_ichebyshevtransform!,
                        pochhammer, lgamma, chebyshevtransform!, ichebyshevtransform!

import BlockBandedMatrices: blockbandwidths, subblockbandwidths

# we need to import all special functions to use Calculus.symbolic_derivatives_1arg
import SpecialFunctions: erfcx, dawson, erf,
                    hankelh1, hankelh2, besselj, bessely, besseli, besselk,
                    besselkx, hankelh1x, hankelh2x,
                    expm1, eta, gamma, erfc

using StaticArrays: SVector

points(d::IntervalOrSegmentDomain{T},n::Integer) where {T} =
    fromcanonical.(Ref(d), chebyshevpoints(float(real(eltype(T))), n))  # eltype to handle point
bary(v::AbstractVector{Float64},d::IntervalOrSegmentDomain,x::Float64) = bary(v,tocanonical(d,x))

strictconvert(T::Type, x) = convert(T, x)::T

include("bary.jl")


include("ultraspherical.jl")
include("Domains/Domains.jl")
include("Spaces/Spaces.jl")
include("roots.jl")
include("specialfunctions.jl")
include("fastops.jl")
include("show.jl")

end
