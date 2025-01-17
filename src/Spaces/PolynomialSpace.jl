export PolynomialSpace, NormalizedPolynomialSpace

## Orthogonal polynomials

abstract type PolynomialSpace{D,R} <: Space{D,R} end

@containsconstants PolynomialSpace

Multiplication(f::Fun{U},sp::PolynomialSpace) where {U<:PolynomialSpace} = ConcreteMultiplication(f,sp)
bandwidths(M::ConcreteMultiplication{U,V}) where {U<:PolynomialSpace,V<:PolynomialSpace} =
    (ncoefficients(M.f)-1,ncoefficients(M.f)-1)
rangespace(M::ConcreteMultiplication{U,V}) where {U<:PolynomialSpace,V<:PolynomialSpace} = domainspace(M)




## Evaluation

function evaluate(f::AbstractVector,S::PolynomialSpace,x)
    if x in domain(S)
        clenshaw(S,f,tocanonical(S,x))
    elseif isambiguous(domain(S))
        length(f) == 0 && return zero(eltype(f))
        for k = 2:length(f)
            iszero(f[k]) || throw(ArgumentError("Ambiguous domains only work with constants"))
        end
        return first(f)
    else
        zero(eltype(f))
    end
end

# we need the ... for multi-dimensional
evaluate(f::AbstractVector,S::PolynomialSpace,x,y,z...) =
    evaluate(f,S,SVector(x,y,z...))

function evaluate(f::AbstractVector, S::PolynomialSpace, x::Fun)
    if issubset(Interval(minimum(x),maximum(x)),domain(S))
        clenshaw(S,f,tocanonical(S,x))
    else
        error("Implement splitatpoints for evaluate ")
    end
end

## Extrapolation
extrapolate(f::AbstractVector,S::PolynomialSpace,x) = clenshaw(S,f,tocanonical(S,x))

######
# Recurrence encodes the recurrence coefficients
# or equivalently multiplication by x
######
struct Recurrence{S,T} <: TridiagonalOperator{T}
    space::S
end

Recurrence(sp) = Recurrence{typeof(sp),rangetype(sp)}(sp)

convert(::Type{Operator{T}},J::Recurrence{S}) where {T,S} = Recurrence{S,T}(J.space)

domainspace(R::Recurrence) = R.space
rangespace(R::Recurrence) = R.space


#####
# recα/β/γ are given by
#       x p_{n-1} =γ_n p_{n-2} + α_n p_{n-1} +  p_n β_n
#####

function getindex(R::Recurrence{S,T},k::Integer,j::Integer) where {S,T}
    if j==k-1
        recβ(T,R.space,k-1)
    elseif j==k
        recα(T,R.space,k)
    elseif j==k+1
        recγ(T,R.space,k+1)
    else
        zero(T)
    end
end

######
# JacobiZ encodes [BasisFunctional(1);(J-z*I)[2:end,:]]
# where J is the Jacobi operator
######
struct JacobiZ{S<:Space,T} <: TridiagonalOperator{T}
    space::S
    z::T
end

JacobiZ(sp::PolynomialSpace,z) =
    (T = promote_type(prectype(sp),typeof(z)); JacobiZ{typeof(sp),T}(sp,strictconvert(T,z)))

convert(::Type{Operator{T}},J::JacobiZ{S}) where {T,S} = JacobiZ{S,T}(J.space,J.z)

domainspace(::JacobiZ) = ℓ⁰
rangespace(::JacobiZ) = ℓ⁰

#####
# recα/β/γ are given by
#       x p_{n-1} =γ_n p_{n-2} + α_n p_{n-1} +  p_n β_n
#####

function getindex(J::JacobiZ{S,T},k::Integer,j::Integer) where {S,T}
    if j==k-1
        recγ(T,J.space,k)
    elseif j==k
        k == 1 ? one(T) : recα(T,J.space,k)-J.z
    elseif j==k+1 && k > 1
        recβ(T,J.space,k)
    else
        zero(T)
    end
end




#####
# Multiplication can be built from recurrence coefficients
#  multiplication by J=M[x] is Recurrence operator
#  and assume p_0 = 1, then we have
#
#   M[p_0] = 1
#   M[p_1] = (J/β_1 - α_1/β_1)*M[p_0]
#   M[p_k] = (J/β_k - α_k/β_k)*M[p_{k-1}] - γ_k/β_k*M[p_{k-2}]
#####


getindex(M::ConcreteMultiplication{C,PS,T},k::Integer,j::Integer) where {PS<:PolynomialSpace,T,C<:PolynomialSpace} = M[k:k,j:j][1,1]




# Fast implementation of C[:,:] = α*J*B+β*C where the bandediwth of B is
# specified by b, not by the parameters in B
function jac_gbmm!(α, J, B, β, C, b)
    if β ≠ 1
        lmul!(β,C)
    end

    Jp = view(J, band(1))
    J0 = view(J, band(0))
    Jm = view(J, band(-1))
    n = size(J,1)

    Cn, Cm = size(C)

    @views for k=-1:b-1
        if 1-Cn ≤ b-k ≤ Cm-1 # if inbands
            C[band(b-k)] .+= α.*B[band(b-k-1)][2:n-b+k+1].*Jp[1:n-b+k]
            if k ≥ 0
                C[band(b-k)] .+= α.*B[band(b-k)].*J0[1:n-b+k]
                if k ≥ 1
                    C[band(b-k)][2:n-b+k] .+= α.*B[band(b-k+1)].*Jm[1:n-1-b+k]
                end
            end
        end
    end

    @views for k=-1:b-1
        if 1-Cn ≤ k-b ≤ Cm-1 # if inbands
            C[band(k-b)] .+= α.*B[band(k-b+1)][1:n-b+k].*Jm[b-k:n-1]
            if k ≥ 0
                C[band(k-b)] .+= α.*B[band(k-b)].*J0[b-k+1:n]
                if k ≥ 1
                    C[band(k-b)][1:n-b+k-1] .+= α.*B[band(k-b-1)].*Jp[b-k+1:n-1]
                end
            end
        end
    end

    @views begin
        C[band(0)] .+= α.*B[band(0)].*J0
        C[band(0)][1:n-1] .+= α.*B[band(-1)].*Jp
        C[band(0)][2:n] .+= α.*B[band(1)].*Jm
    end

    C
end

function BandedMatrix(S::SubOperator{T,ConcreteMultiplication{C,PS,T},
                                     Tuple{UnitRange{Int},UnitRange{Int}}}) where {PS<:PolynomialSpace,T,C<:PolynomialSpace}
    M=parent(S)
    kr,jr=parentindices(S)
    f=M.f
    a=f.coefficients
    sp=space(f)
    n=length(a)

    if n==0
        return BandedMatrix(Zeros, S)
    elseif n==1
        ret = BandedMatrix(Zeros, S)
        shft=kr[1]-jr[1]
        ret[band(shft)] .= a[1]
        return ret::BandedMatrix{T}
    elseif n==2
        # we have U_x = [1 α-x; 0 β]
        # for e_1^⊤ U_x\a == a[1]*I-(α-J)*a[2]/β == (a[1]-α*a[2]/β)*I + J*a[2]/β
        # implying
        α,β=recα(T,sp,1),recβ(T,sp,1)
        ret=Operator{T}(Recurrence(M.space))[kr,jr]::BandedMatrix{T}
        lmul!(a[2]/β,ret)
        shft=kr[1]-jr[1]
        ret[band(shft)] .+= a[1]-α*a[2]/β
        return ret::BandedMatrix{T}
    end

    jkr=max(1,min(jr[1],kr[1])-(n-1)÷2):max(jr[end],kr[end])+(n-1)÷2

    #Multiplication is transpose
    J=Operator{T}(Recurrence(M.space))[jkr,jkr]

    B=n-1  # final bandwidth

    # Clenshaw for operators
    Bk2 = BandedMatrix(Zeros{T}(size(J,1),size(J,2)), (B,B))
    Bk2[band(0)] .= a[n]/recβ(T,sp,n-1)
    α,β = recα(T,sp,n-1),recβ(T,sp,n-2)
    Bk1 = (-α/β)*Bk2
    view(Bk1, band(0)) .= (a[n-1]/β) .+ view(Bk1, band(0))
    jac_gbmm!(one(T)/β,J,Bk2,one(T),Bk1,0)
    b=1  # we keep track of bandwidths manually to reuse memory
    for k=n-2:-1:2
        α,β,γ=recα(T,sp,k),recβ(T,sp,k-1),recγ(T,sp,k+1)
        lmul!(-γ/β,Bk2)
        view(Bk2, band(0)) .= (a[k]/β) .+ view(Bk2, band(0))
        jac_gbmm!(1/β,J,Bk1,one(T),Bk2,b)
        LinearAlgebra.axpy!(-α/β,Bk1,Bk2)
        Bk2,Bk1=Bk1,Bk2
        b+=1
    end
    α,γ=recα(T,sp,1),recγ(T,sp,2)
    lmul!(-γ,Bk2)
    view(Bk2, band(0)) .= a[1] .+ view(Bk2, band(0))
    jac_gbmm!(one(T),J,Bk1,one(T),Bk2,b)
    LinearAlgebra.axpy!(-α,Bk1,Bk2)

    # relationship between jkr and kr, jr
    kr2,jr2=kr.-jkr[1].+1,jr.-jkr[1].+1

    # TODO: reuse memory of Bk2, though profile suggests it's not too important
    BandedMatrix(view(Bk2,kr2,jr2))::BandedMatrix{T}
end




## All polynomial spaces can be converted provided spaces match

isconvertible(a::PolynomialSpace,b::PolynomialSpace) = domain(a) == domain(b)
union_rule(a::PolynomialSpace{D},b::PolynomialSpace{D}) where {D} =
    domainscompatible(a,b) ? (a < b ? a : b) : NoSpace()   # the union of two polys is always a poly



## General clenshaw
clenshaw(sp::PolynomialSpace,c::AbstractVector,x::AbstractArray) = clenshaw(c,x,
                                            ClenshawPlan(promote_type(eltype(c),eltype(x)),sp,length(c),length(x)))
clenshaw(sp::PolynomialSpace,c::AbstractMatrix,x::AbstractArray) = clenshaw(c,x,ClenshawPlan(promote_type(eltype(c),eltype(x)),sp,size(c,1),length(x)))
clenshaw(sp::PolynomialSpace,c::AbstractMatrix,x) = clenshaw(c,x,ClenshawPlan(promote_type(eltype(c),typeof(x)),sp,size(c,1),size(c,2)))

clenshaw!(sp::PolynomialSpace,c::AbstractVector,x::AbstractVector)=clenshaw!(c,x,ClenshawPlan(promote_type(eltype(c),eltype(x)),sp,length(x)))

function clenshaw(sp::PolynomialSpace,c::AbstractVector,x)
    N,T = length(c),promote_type(prectype(sp),eltype(c),typeof(x))
    TT = eltype(T)
    if isempty(c)
        return zero(T)
    end

    bk1,bk2 = zero(T),zero(T)
    A,B,C = recA(TT,sp,N-1),recB(TT,sp,N-1),recC(TT,sp,N)
    for k = N:-1:2
        bk2, bk1 = bk1, muladd(muladd(A,x,B),bk1,muladd(-C,bk2,c[k])) # muladd(-C,bk2,muladd(muladd(A,x,B),bk1,c[k])) # (A*x+B)*bk1+c[k]-C*bk2
        A,B,C = recA(TT,sp,k-2),recB(TT,sp,k-2),recC(TT,sp,k-1)
    end
    muladd(muladd(A,x,B),bk1,muladd(-C,bk2,c[1])) # muladd(-C,bk2,muladd(muladd(A,x,B),bk1,c[1])) # (A*x+B)*bk1+c[1]-C*bk2
end



# evaluate polynomial
# indexing starts from 0
function forwardrecurrence(::Type{T},S::Space,r::AbstractRange,x::Number) where T
    if isempty(r)
        return T[]
    end
    n=maximum(r)+1
    v=Vector{T}(undef, n)  # x may be complex
    if n > 0
        v[1]=1
        if n > 1
            v[2] = muladd(recA(T,S,0),x,recB(T,S,0))
            @inbounds for k=2:n-1
                v[k+1]=muladd(muladd(recA(T,S,k-1),x,recB(T,S,k-1)),v[k],-recC(T,S,k-1)*v[k-1])
            end
        end
    end

    return v[r.+1]
end

getindex(op::ConcreteEvaluation{<:PolynomialSpace}, k::Integer) = op[k:k][1]
# avoid ambiguity
for OP in (:leftendpoint, :rightendpoint)
    @eval getindex(op::ConcreteEvaluation{<:PolynomialSpace,typeof($OP)},k::Integer) =
        op[k:k][1]
end

function getindex(op::ConcreteEvaluation{J,typeof(leftendpoint)},kr::AbstractRange) where J<:PolynomialSpace
    _getindex_evaluation(op, leftendpoint(domain(op)), kr)
end

function getindex(op::ConcreteEvaluation{J,typeof(rightendpoint)},kr::AbstractRange) where J<:PolynomialSpace
    _getindex_evaluation(op, rightendpoint(domain(op)), kr)
end

function getindex(op::ConcreteEvaluation{J,TT}, kr::AbstractRange) where {J<:PolynomialSpace,TT<:Number}
    _getindex_evaluation(op, op.x, kr)
end

function _getindex_evaluation(op::ConcreteEvaluation{<:PolynomialSpace}, x, kr::AbstractRange)
    _getindex_evaluation(eltype(op), op.space, op.order, x, kr)
end

function _getindex_evaluation(::Type{T}, sp, order, x, kr::AbstractRange) where {T}
    Base.require_one_based_indexing(kr)
    isempty(kr) && return zeros(T, 0)
    if order == 0
        forwardrecurrence(T,sp,kr .- 1,tocanonical(sp,x))
    else
        z = Zeros{T}(length(range(minimum(kr), order, step=step(kr))))
        kr_red = kr .- (order + 1)
        polydegrees = reverse(range(maximum(kr_red), max(0, minimum(kr_red)), step=-step(kr)))
        D = Derivative(sp, order)
        if !isempty(polydegrees)
            P = forwardrecurrence(T, rangespace(D), polydegrees, tocanonical(sp,x))
            # in case the derivative has only one non-zero band, the matrix-vector
            # multiplication simplifies considerably.
            # This branch is particularly useful for ConcreteDerivatives where
            # indexing is fast, as the non-zero band may be computed without
            # evaluating the matrix
            if bandwidth(D, 1) == -bandwidth(D, 2)
                d = nonzeroband(T, D, polydegrees, order)
                Pd = P .* d
                if !isempty(z)
                    Pd = T[z; Pd]
                end
            else
                # in general, this is a banded matrix-vector product
                Dtv = view(transpose(D), kr, 1:length(P))
                Pd = strictconvert(Vector{T},  mul_coefficients(Dtv, P))
            end
        else
            Pd = T[z;]
        end
        Pd
    end
end

function nonzeroband(::Type{T}, D::ConcreteDerivative, polydegrees, order) where {T}
    bw = bandwidth(D, 2)
    T[D[k+1, k+1+bw] for k in polydegrees]
end
function nonzeroband(::Type{T}, D, polydegrees, order) where {T}
    bw = bandwidth(D, 2)
    rows = 1:(maximum(polydegrees) + order + 1)
    B = D[rows, rows .+ bw]
    Bv = @view B[diagind(B)]
    Bv[polydegrees .+ 1]
end


struct NormalizedPolynomialSpace{S,D,R} <: Space{D,R}
    space::S
    NormalizedPolynomialSpace{S,D,R}(space) where {S,D,R} = new{S,D,R}(space)
end

@containsconstants NormalizedPolynomialSpace

domain(S::NormalizedPolynomialSpace) = domain(S.space)
canonicalspace(S::NormalizedPolynomialSpace) = S.space
setdomain(NS::NormalizedPolynomialSpace, d::Domain) = NormalizedPolynomialSpace(setdomain(canonicalspace(NS), d))

NormalizedPolynomialSpace(space::PolynomialSpace{D,R}) where {D,R} = NormalizedPolynomialSpace{typeof(space),D,R}(space)

function Conversion(L::NormalizedPolynomialSpace{S}, M::S) where S<:PolynomialSpace
    if L.space == M
        ConcreteConversion(L, M)
    else
        sp = L.space
        ConversionWrapper(TimesOperator(Conversion(sp, M), Conversion(L, sp)))
    end
end

function Conversion(L::S, M::NormalizedPolynomialSpace{S}) where S<:PolynomialSpace
    if M.space == L
        ConcreteConversion(L, M)
    else
        sp = M.space
        ConversionWrapper(TimesOperator(Conversion(sp, M), Conversion(L, sp)))
    end
end

function Fun(::typeof(identity), S::NormalizedPolynomialSpace)
    C = canonicalspace(S)
    f = Fun(identity, C)
    coeffs = coefficients(f)
    CS = ConcreteConversion(C, S)
    ApproxFunBase.mul_coefficients!(CS, coeffs)
    Fun(S, coeffs)
end

function conversion_rule(a::NormalizedPolynomialSpace{S}, b::S) where S<:PolynomialSpace
    domainscompatible(domain(a), domain(b)) ? a : NoSpace()
end

bandwidths(C::ConcreteConversion{NormalizedPolynomialSpace{S,D,R},S}) where {S,D,R} = (0, 0)
bandwidths(C::ConcreteConversion{S,NormalizedPolynomialSpace{S,D,R}}) where {S,D,R} = (0, 0)

function getindex(C::ConcreteConversion{NormalizedPolynomialSpace{S,D,R},S,T},k::Integer,j::Integer) where {S,D<:IntervalOrSegment,R,T}
    if j==k
        inv(sqrt(normalization(T, C.rangespace, k-1)*arclength(domain(C.rangespace))/2))
    else
        zero(T)
    end
end

function getindex(C::ConcreteConversion{S,NormalizedPolynomialSpace{S,D,R},T},k::Integer,j::Integer) where {S,D<:IntervalOrSegment,R,T}
    if j==k
        sqrt(normalization(T, C.domainspace, k-1)*arclength(domain(C.domainspace))/2)
    else
        zero(T)
    end
end

function getindex(C::ConcreteConversion{NormalizedPolynomialSpace{S,D,R},S,T},k::Integer,j::Integer) where {S,D<:Ray,R,T}
    if j==k
        inv(sqrt(normalization(T, C.rangespace, k-1)))
    else
        zero(T)
    end
end

function getindex(C::ConcreteConversion{S,NormalizedPolynomialSpace{S,D,R},T},k::Integer,j::Integer) where {S,D<:Ray,R,T}
    if j==k
        sqrt(normalization(T, C.domainspace, k-1))
    else
        zero(T)
    end
end

spacescompatible(a::NormalizedPolynomialSpace,b::NormalizedPolynomialSpace) = spacescompatible(a.space,b.space)
hasconversion(a::PolynomialSpace,b::NormalizedPolynomialSpace) = hasconversion(a,b.space)
hasconversion(a::NormalizedPolynomialSpace,b::PolynomialSpace) = hasconversion(a.space,b)
hasconversion(a::NormalizedPolynomialSpace,b::NormalizedPolynomialSpace) = hasconversion(a.space,b)


function Multiplication(f::Fun{U},sp::NormalizedPolynomialSpace) where U <: PolynomialSpace
    fsp = space(f)
    unnorm_sp = sp.space
    O = Conversion(unnorm_sp,sp) *
            Multiplication(f,unnorm_sp) * Conversion(sp, unnorm_sp)
    MultiplicationWrapper(f, O)
end

function Multiplication(f::Fun{U},sp::PolynomialSpace) where U <: NormalizedPolynomialSpace
    Multiplication(Conversion(space(f), canonicalspace(f))*f, sp)
end

function Multiplication(f::Fun{U},sp::NormalizedPolynomialSpace) where U <: NormalizedPolynomialSpace
    csp = canonicalspace(f)
    fc = Conversion(space(f), csp)*f
    Multiplication(fc, sp)
end
