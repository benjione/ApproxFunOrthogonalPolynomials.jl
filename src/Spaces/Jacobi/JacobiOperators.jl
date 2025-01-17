## Derivative

function Derivative(J::Jacobi,k::Integer)
    k==1 ? ConcreteDerivative(J,1) :
        DerivativeWrapper(
            TimesOperator(
                Derivative(Jacobi(J.b+1,J.a+1,J.domain),k-1),ConcreteDerivative(J,1)),
        J, k)
end



rangespace(D::ConcreteDerivative{J}) where {J<:Jacobi}=Jacobi(D.space.b+D.order,D.space.a+D.order,domain(D))
bandwidths(D::ConcreteDerivative{J}) where {J<:Jacobi}=-D.order,D.order

getindex(T::ConcreteDerivative{J},k::Integer,j::Integer) where {J<:Jacobi} =
    j==k+1 ? eltype(T)((k+1+T.space.a+T.space.b)/complexlength(domain(T))) : zero(eltype(T))


# Evaluation

Evaluation(S::Jacobi,x::typeof(leftendpoint),o::Integer) =
    ConcreteEvaluation(S,x,o)
Evaluation(S::Jacobi,x::typeof(rightendpoint),o::Integer) =
    ConcreteEvaluation(S,x,o)
Evaluation(S::Jacobi,x::Number,o::Integer) = ConcreteEvaluation(S,x,o)

Evaluation(S::NormalizedPolynomialSpace{<:Jacobi},x::typeof(leftendpoint),o::Integer) =
    ConcreteEvaluation(S,x,o)
Evaluation(S::NormalizedPolynomialSpace{<:Jacobi},x::typeof(rightendpoint),o::Integer) =
    ConcreteEvaluation(S,x,o)
Evaluation(S::NormalizedPolynomialSpace{<:Jacobi},x::Number,o::Integer) = ConcreteEvaluation(S,x,o)

## Integral

function Integral(J::Jacobi,k::Integer)
    if k > 1
        Q=Integral(J,1)
        IntegralWrapper(TimesOperator(Integral(rangespace(Q),k-1),Q),J,k)
    elseif J.a > 0 && J.b > 0   # we have a simple definition
        ConcreteIntegral(J,1)
    else   # convert and then integrate
        sp=Jacobi(J.b+1,J.a+1,domain(J))
        C=Conversion(J,sp)
        Q=Integral(sp,1)
        IntegralWrapper(TimesOperator(Q,C),J,1)
    end
end


rangespace(D::ConcreteIntegral{J}) where {J<:Jacobi}=Jacobi(D.space.b-D.order,D.space.a-D.order,domain(D))
bandwidths(D::ConcreteIntegral{J}) where {J<:Jacobi}=D.order,0

function getindex(T::ConcreteIntegral{J},k::Integer,j::Integer) where J<:Jacobi
    @assert T.order==1
    if k≥2 && j==k-1
        complexlength(domain(T))./(k+T.space.a+T.space.b-2)
    else
        zero(eltype(T))
    end
end


## Volterra Integral operator

Volterra(d::IntervalOrSegment) = Volterra(Legendre(d))
function Volterra(S::Jacobi, order::Integer)
    @assert S.a == S.b == 0.0
    @assert order==1
    ConcreteVolterra(S,order)
end

rangespace(V::ConcreteVolterra{J}) where {J<:Jacobi}=Jacobi(-1.0,0.0,domain(V))
bandwidths(V::ConcreteVolterra{J}) where {J<:Jacobi}=1,0

function getindex(V::ConcreteVolterra{J},k::Integer,j::Integer) where J<:Jacobi
    d=domain(V)
    C = complexlength(d)/2
    if k≥2
        if j==k-1
            C/(k-1.5)
        elseif j==k
            -C/(k-0.5)
        else
            zero(eltype(V))
        end
    else
        zero(eltype(V))
    end
end


for (Func,Len,Sum) in ((:DefiniteIntegral,:complexlength,:sum),(:DefiniteLineIntegral,:arclength,:linesum))
    ConcFunc = Symbol(:Concrete, Func)

    @eval begin
        $Func(S::Jacobi{<:IntervalOrSegment}) = $ConcFunc(S)

        function getindex(Σ::$ConcFunc{Jacobi{D,R},T},k::Integer) where {D<:IntervalOrSegment,R,T}
            dsp = domainspace(Σ)

            if dsp.b == dsp.a == 0
                # TODO: copy and paste
                k == 1 ? strictconvert(T,$Sum(Fun(dsp,[one(T)]))) : zero(T)
            else
                strictconvert(T,$Sum(Fun(dsp,[zeros(T,k-1);1])))
            end
        end

        function bandwidths(Σ::$ConcFunc{Jacobi{D,R}}) where {D<:IntervalOrSegment,R}
            if domainspace(Σ).b == domainspace(Σ).a == 0
                0,0  # first entry
            else
                0,ℵ₀
            end
        end
    end
end



## Conversion
# We can only increment by a or b by one, so the following
# multiplies conversion operators to handle otherwise

function Conversion(L::Jacobi,M::Jacobi)
    domain(L) == reverseorientation(domain(M)) &&
        return ConversionWrapper(Conversion(reverseorientation(L), M)*ReverseOrientation(L))

    domain(L) == domain(M) || domain(L) == reverseorientation(domain(M)) ||
        throw(ArgumentError("Domains must be the same"))

    if isapproxinteger(L.a-M.a) && isapproxinteger(L.b-M.b)
        dm=domain(M)
        D=typeof(dm)
        if isapprox(M.a,L.a) && isapprox(M.b,L.b)
            ConversionWrapper(Operator(I,L))
        elseif (isapprox(M.b,L.b+1) && isapprox(M.a,L.a)) || (isapprox(M.b,L.b) && isapprox(M.a,L.a+1))
            ConcreteConversion(L,M)
        elseif M.b > L.b+1
            ConversionWrapper(TimesOperator(Conversion(Jacobi(M.b-1,M.a,dm),M),Conversion(L,Jacobi(M.b-1,M.a,dm))))
        else  #if M.a >= L.a+1
            ConversionWrapper(TimesOperator(Conversion(Jacobi(M.b,M.a-1,dm),M),Conversion(L,Jacobi(M.b,M.a-1,dm))))
        end
    elseif L.a ≈ L.b ≈ 0. && M.a ≈ M.b ≈ 0.5
        Conversion(L,Ultraspherical(L),Ultraspherical(M),M)
    elseif L.a ≈ L.b ≈ 0. && M.a ≈ M.b ≈ -0.5
        Conversion(L,Ultraspherical(L),Chebyshev(M),M)
    elseif L.a ≈ L.b ≈ -0.5 && M.a ≈ M.b ≈ 0.5
        Conversion(L,Chebyshev(L),Ultraspherical(M),M)
    else # L.a - M.a ≈ L.b - M.b
        error("Implement for $L → $M")
    end
end

bandwidths(C::ConcreteConversion{J1,J2}) where {J1<:Jacobi,J2<:Jacobi}=(0,1)



function Base.getindex(C::ConcreteConversion{J1,J2,T},k::Integer,j::Integer) where {J1<:Jacobi,J2<:Jacobi,T}
    L=C.domainspace
    if L.b+1==C.rangespace.b
        if j==k
            k==1 ? strictconvert(T,1) : strictconvert(T,(L.a+L.b+k)/(L.a+L.b+2k-1))
        elseif j==k+1
            strictconvert(T,(L.a+k)./(L.a+L.b+2k+1))
        else
            zero(T)
        end
    elseif L.a+1==C.rangespace.a
        if j==k
            k==1 ? strictconvert(T,1) : strictconvert(T,(L.a+L.b+k)/(L.a+L.b+2k-1))
        elseif j==k+1
            strictconvert(T,-(L.b+k)./(L.a+L.b+2k+1))
        else
            zero(T)
        end
    else
        error("Not implemented")
    end
end




# return the space that has banded Conversion to the other
function conversion_rule(A::Jacobi,B::Jacobi)
    if !isapproxinteger(A.a-B.a) || !isapproxinteger(A.b-B.b)
        NoSpace()
    else
        Jacobi(min(A.b,B.b),min(A.a,B.a),domain(A))
    end
end



## Ultraspherical Conversion

# Assume m is compatible

function Conversion(A::PolynomialSpace,B::Jacobi)
    J = Jacobi(A)
    J == B ? ConcreteConversion(A,B) :
             ConversionWrapper(TimesOperator(Conversion(J,B),Conversion(A,J)))
end

function Conversion(A::Jacobi,B::PolynomialSpace)
    J = Jacobi(B)
    J == A ? ConcreteConversion(A,B) :
             ConversionWrapper(TimesOperator(Conversion(J,B),Conversion(A,J)))
end

function Conversion(A::Jacobi,B::Chebyshev)
    if A.a == A.b == -0.5
        ConcreteConversion(A,B)
    elseif A.a == A.b == 0
        ConversionWrapper(
            SpaceOperator(
                ConcreteConversion(Ultraspherical(1//2),B),
                A,B))
    elseif A.a == A.b
        US = Ultraspherical(A)
        ConversionWrapper(Conversion(US,B)*ConcreteConversion(A,US))
    else
        J = Jacobi(B)
        ConcreteConversion(J,B)*Conversion(A,J)
    end
end

function Conversion(A::Chebyshev,B::Jacobi)
    if B.a == B.b == -0.5
        ConcreteConversion(A,B)
    elseif B.a == B.b == 0
        ConversionWrapper(
            SpaceOperator(
                ConcreteConversion(A,Ultraspherical(1//2,domain(B))),
                A,B))
    elseif B.a == B.b
        US = Ultraspherical(B)
        ConcreteConversion(US,B) * Conversion(A,US)
    else
        J = Jacobi(A)
        Conversion(J,B)*ConcreteConversion(A,J)
    end
end


function Conversion(A::Jacobi,B::Ultraspherical)
    if A.a == A.b == -0.5
        ConversionWrapper(Conversion(Chebyshev(domain(A)),B)*
            ConcreteConversion(A,Chebyshev(domain(A))))
    elseif A.a == A.b == order(B)-0.5
        ConcreteConversion(A,B)
    elseif A.a == A.b == 0
        ConversionWrapper(
            SpaceOperator(
                Conversion(Ultraspherical(1//2),B),
                A,B))
    elseif A.a == A.b
        US = Ultraspherical(A)
        ConversionWrapper(Conversion(US,B)*ConcreteConversion(A,US))
    else
        J = Jacobi(B)
        ConcreteConversion(J,B)*Conversion(A,J)
    end
end

function Conversion(A::Ultraspherical,B::Jacobi)
    if B.a == B.b == -0.5
        ConversionWrapper(ConcreteConversion(Chebyshev(domain(A)),B)*
            Conversion(A,Chebyshev(domain(A))))
    elseif B.a == B.b == order(A)-0.5
        ConcreteConversion(A,B)
    elseif B.a == B.b == 0
        ConversionWrapper(
            SpaceOperator(
                Conversion(A,Ultraspherical(1//2,domain(B))),
                A,B))
    elseif B.a == B.b
        US = Ultraspherical(B)
        ConversionWrapper(ConcreteConversion(US,B)*Conversion(A,US))
    else
        J = Jacobi(A)
        Conversion(J,B)*ConcreteConversion(A,J)
    end
end




bandwidths(C::ConcreteConversion{US,J}) where {US<:Chebyshev,J<:Jacobi} = 0,0
bandwidths(C::ConcreteConversion{J,US}) where {US<:Chebyshev,J<:Jacobi} = 0,0


bandwidths(C::ConcreteConversion{US,J}) where {US<:Ultraspherical,J<:Jacobi} = 0,0
bandwidths(C::ConcreteConversion{J,US}) where {US<:Ultraspherical,J<:Jacobi} = 0,0

#TODO: Figure out how to unify these definitions
function getindex(C::ConcreteConversion{CC,J,T},k::Integer,j::Integer) where {J<:Jacobi,CC<:Chebyshev,T}
    if j==k
        one(T)/jacobip(T,k-1,-one(T)/2,-one(T)/2,one(T))
    else
        zero(T)
    end
end

function BandedMatrix(S::SubOperator{T,ConcreteConversion{CC,J,T},Tuple{UnitRange{Int},UnitRange{Int}}}) where {J<:Jacobi,CC<:Chebyshev,T}
    ret=BandedMatrix(Zeros, S)
    kr,jr = parentindices(S)
    k=(kr ∩ jr)

    vals = one(T)./jacobip(T,k .- 1,-one(T)/2,-one(T)/2,one(T))

    ret[band(bandshift(S))] = vals
    ret
end


function getindex(C::ConcreteConversion{J,CC,T},k::Integer,j::Integer) where {J<:Jacobi,CC<:Chebyshev,T}
    if j==k
        jacobip(T,k-1,-one(T)/2,-one(T)/2,one(T))
    else
        zero(T)
    end
end

function BandedMatrix(S::SubOperator{T,ConcreteConversion{J,CC,T},Tuple{UnitRange{Int},UnitRange{Int}}}) where {J<:Jacobi,CC<:Chebyshev,T}
    ret=BandedMatrix(Zeros, S)
    kr,jr = parentindices(S)
    k=(kr ∩ jr)

    vals = jacobip(T,k.-1,-one(T)/2,-one(T)/2,one(T))

    ret[band(bandshift(S))] = vals
    ret
end


function getindex(C::ConcreteConversion{US,J,T},k::Integer,j::Integer) where {US<:Ultraspherical,J<:Jacobi,T}
    if j==k
        S=rangespace(C)
        jp=jacobip(T,k-1,S.a,S.b,one(T))
        um=strictconvert(Operator{T}, Evaluation(setcanonicaldomain(domainspace(C)),rightendpoint,0))[k]::T
        (um/jp)::T
    else
        zero(T)
    end
end

function BandedMatrix(S::SubOperator{T,ConcreteConversion{US,J,T},Tuple{UnitRange{Int},UnitRange{Int}}}) where {US<:Ultraspherical,J<:Jacobi,T}
    ret=BandedMatrix(Zeros, S)
    kr,jr = parentindices(S)
    k=(kr ∩ jr)

    sp=rangespace(parent(S))
    jp=jacobip(T,k.-1,sp.a,sp.b,one(T))
    um=Evaluation(T,setcanonicaldomain(domainspace(parent(S))),rightendpoint,0)[k]
    vals = um./jp

    ret[band(bandshift(S))] = vals
    ret
end



function getindex(C::ConcreteConversion{J,US,T},k::Integer,j::Integer) where {US<:Ultraspherical,J<:Jacobi,T}
    if j==k
        S=domainspace(C)
        jp=jacobip(T,k-1,S.a,S.b,one(T))
        um=Evaluation(T,setcanonicaldomain(rangespace(C)),rightendpoint,0)[k]
        jp/um::T
    else
        zero(T)
    end
end

function BandedMatrix(S::SubOperator{T,ConcreteConversion{J,US,T},Tuple{UnitRange{Int},UnitRange{Int}}}) where {US<:Ultraspherical,J<:Jacobi,T}
    ret=BandedMatrix(Zeros, S)
    kr,jr = parentindices(S)
    k=(kr ∩ jr)

    sp=domainspace(parent(S))
    jp=jacobip(T,k.-1,sp.a,sp.b,one(T))
    um=Evaluation(T,setcanonicaldomain(rangespace(parent(S))),rightendpoint,0)[k]
    vals = jp./um

    ret[band(bandshift(S))] = vals
    ret
end






function union_rule(A::Jacobi,B::Jacobi)
    if domainscompatible(A,B)
        Jacobi(min(A.b,B.b),min(A.a,B.a),domain(A))
    else
        NoSpace()
    end
end

function maxspace_rule(A::Jacobi,B::Jacobi)
    if isapproxinteger(A.a-B.a) && isapproxinteger(A.b-B.b)
        Jacobi(max(A.b,B.b),max(A.a,B.a),domain(A))
    else
        NoSpace()
    end
end


function union_rule(A::Chebyshev,B::Jacobi)
    if domainscompatible(A, B)
        if isapprox(B.a,-0.5) && isapprox(B.b,-0.5)
            # the spaces are the same
            A
        else
            union(Jacobi(A),B)
        end
    else
        if isapprox(B.a,-0.5) && isapprox(B.b,-0.5)
            union(A, Chebyshev(domain(B)))
        else
            NoSpace()
        end
    end
end
function union_rule(A::Ultraspherical,B::Jacobi)
    m=order(A)
    if domainscompatible(A, B)
        if isapprox(B.a,m-0.5) && isapprox(B.b,m-0.5)
            # the spaces are the same
            A
        else
            union(Jacobi(A),B)
        end
    else
        if isapprox(B.a,m-0.5) && isapprox(B.b,m-0.5)
            union(A, Ultraspherical(m, domain(B)))
        else
            NoSpace()
        end
    end
end

for (OPrule,OP) in ((:conversion_rule,:conversion_type), (:maxspace_rule,:maxspace))
    @eval begin
        function $OPrule(A::Chebyshev,B::Jacobi)
            if B.a ≈ -0.5 && B.b ≈ -0.5
                # the spaces are the same
                A
            elseif isapproxinteger(B.a+0.5) && isapproxinteger(B.b+0.5)
                $OP(Jacobi(A),B)
            else
                NoSpace()
            end
        end
        function $OPrule(A::Ultraspherical,B::Jacobi)
            m = order(A)
            if B.a ≈ m-0.5 && B.b ≈ m-0.5
                # the spaces are the same
                A
            elseif isapproxinteger(B.a+0.5) && isapproxinteger(B.b+0.5)
                $OP(Jacobi(A),B)
            else
                NoSpace()
            end
        end
    end
end

hasconversion(a::Jacobi,b::Chebyshev) = hasconversion(a,Jacobi(b))
hasconversion(a::Chebyshev,b::Jacobi) = hasconversion(Jacobi(a),b)

hasconversion(a::Jacobi,b::Ultraspherical) = hasconversion(a,Jacobi(b))
hasconversion(a::Ultraspherical,b::Jacobi) = hasconversion(Jacobi(a),b)




## Special Multiplication
# special multiplication operators exist when multiplying by
# (1+x) or (1-x) by _decreasing_ the parameter.  Thus the







# represents [b+(1+z)*d/dz] (false) or [a-(1-z)*d/dz] (true)
struct JacobiSD{T} <:Operator{T}
    lr::Bool
    S::Jacobi
end

JacobiSD(lr,S)=JacobiSD{Float64}(lr,S)

convert(::Type{Operator{T}},SD::JacobiSD) where {T}=JacobiSD{T}(SD.lr,SD.S)

domain(op::JacobiSD)=domain(op.S)
domainspace(op::JacobiSD)=op.S
rangespace(op::JacobiSD)=op.lr ? Jacobi(op.S.b+1,op.S.a-1,domain(op.S)) : Jacobi(op.S.b-1,op.S.a+1,domain(op.S))
bandwidths(::JacobiSD)=0,0

function getindex(op::JacobiSD,A,k::Integer,j::Integer)
    m=op.lr ? op.S.a : op.S.b
    if k==j
        k+m-1
    else
        zero(eltype(op))
    end
end
