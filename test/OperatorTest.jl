using ApproxFunOrthogonalPolynomials
using ApproxFunBase
using BlockBandedMatrices
using LinearAlgebra
using Test
using ApproxFunBase: Multiplication, InterlaceOperator, Block, ∞
using ApproxFunBaseTest: testfunctional, testbandedoperator, testraggedbelowoperator,
                        testinfoperator, testblockbandedoperator
using ApproxFunOrthogonalPolynomials: JacobiZ

@verbose @testset "Operator" begin
    @testset "Evaluation" begin
        testfunctional(Evaluation(Ultraspherical(1),0.1))
        d = -4 .. 4
        f = Fun(exp, Ultraspherical(1,d))
        @test f(-4) ≈ Number(ldirichlet()*f) ≈ Number(Evaluation(Ultraspherical(1,d),-4)*f)

        testfunctional(Evaluation(Chebyshev(),0.1,1))
        testfunctional(Evaluation(Chebyshev(),0.1,1)-Evaluation(Chebyshev(),0.1,1))

        let f = Fun(cos)
            @test (Evaluation(Chebyshev(),0.1,1)*f)(0.1)  ≈ f'(0.1)
        end
    end

    @testset "Conversion" begin
        C=Conversion(Ultraspherical(1),Ultraspherical(2))
        testbandedoperator(C)

        @test Matrix(C[1:5,1:5])  ≈   [1.0 0.0 -0.3333333333333333 0.0  0.0
                                              0.0 0.5  0.0               -0.25 0.0
                                              0.0 0.0  0.3333333333333333 0.0 -0.2
                                              0.0 0.0  0.0                0.25 0.0
                                              0.0 0.0  0.0                0.0  0.2]
        d=ChebyshevInterval()
        A=Conversion(Chebyshev(d),Ultraspherical(2,d))
        x = Fun()
        f=Fun(exp)
        @test AbstractMatrix(view(A.op, Block.(1:3), Block.(1:3))) isa BlockSkylineMatrix
        testbandedoperator(A)

        @test norm(A\Fun(x.*f,rangespace(A))-(x.*f)) < 100eps()

        @test (I : Chebyshev() → Chebyshev()) * Fun() ≈ Fun()
    end

    @testset "Derivative" begin
        testbandedoperator(Derivative(Ultraspherical(1)))

        d=Interval(-10.,5.);
        S=Chebyshev(d)


        @test norm(Fun(Fun(Fun(exp,S),Ultraspherical(2,d)),S)-Fun(exp,S)) < 100eps()

        @test copy(view(Derivative(Ultraspherical(1)),1:2,1:2))[1,2] ≈ Derivative(Ultraspherical(1))[1,2]
        @test exp(0.1) ≈ (Derivative()*Fun(exp,Ultraspherical(1)))(0.1)
        D=Derivative(d)
        f = Fun(exp,d)
        @test norm((Conversion(Chebyshev(d),Ultraspherical(2,d))\(D^2*f))-f'') < 200eps()

        f=Fun(x->x^2)
        D=Derivative(domain(f))
        @test norm(D*f-f')<100eps()
    end

    @testset "Toeplitz" begin
        C=ToeplitzOperator([1.,2.,3.],[4.,5.,6.])

        @time testbandedoperator(C)

        @test Matrix(C[1:5,1:5])  ≈  [4.0 5.0 6.0 0.0  0.0
                                             1.0 4.0 5.0 6.0 0.0
                                             2.0 1.0 4.0 5.0 6.0
                                             3.0 2.0 1.0 4.0 5.0
                                             0.0 3.0 2.0 1.0 4.0]

         testbandedoperator(HankelOperator([1.,2.,3.,4.,5.,6.,7.]))
    end

    @testset "Multiplication" begin
        testbandedoperator(Multiplication(Fun(Chebyshev(),[1.,2.,3.]),Chebyshev()))

        x=Fun(identity)
        X=Multiplication(x,space(x))
        f = Fun(exp)
        testbandedoperator(X)

        @test norm(X*f-(x.*f)) < 100eps()


        A=Conversion(Chebyshev(),Ultraspherical(2))*X
        @time testbandedoperator(A)

        @test norm((mul_coefficients(A,f.coefficients))-coefficients(x.*f,rangespace(A))) < 100eps()
    end

    @testset "Integral" begin
        f=Fun(exp)
        d=domain(f)
        Q=Integral(d)
        D=Derivative(d)

        @time testbandedoperator(Q)

        @test norm((Q+I)*f-(integrate(f)+f)) < 100eps()
        @test norm((Q)*f-(integrate(f))) < 100eps()
    end

    @testset "Special functions" begin
        x=Fun(identity)
        @test norm(cos(x)-Fun(cos))<10eps()
        @test norm(sin(x)-Fun(sin))<10eps()
        @test norm(exp(x)-Fun(exp))<10eps()
        @test norm(sin(x)./x-Fun(x->sinc(x/π)))<100eps()
    end

    @testset "Permutation" begin
        P=ApproxFunBase.PermutationOperator([2,1])
        testbandedoperator(P)
        @test P[1:4,1:4] ≈ [0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0]
    end

    @testset "Mixed" begin
        d = ChebyshevInterval()
        D = Derivative(d)
        x = Fun(identity,d)
        A = D*(x*D)
        B = D+x*D^2
        C = x*D^2+D

        testbandedoperator(A)
        testbandedoperator(B)
        testbandedoperator(C)
        @time testbandedoperator(x*D)

        f=Fun(exp)
        @test (A.ops[end]*f)(0.1) ≈ f'(0.1)
        @test ((x*D)*f)(0.1) ≈ 0.1*f'(0.1)
        @test (A*f)(0.1) ≈ f'(0.1)+0.1*f''(0.1)
        @test (B*f)(0.1) ≈ f'(0.1)+0.1*f''(0.1)
        @test (C*f)(0.1) ≈ f'(0.1)+0.1*f''(0.1)


        testbandedoperator(A-B)
        testbandedoperator(B-A)
        testbandedoperator(A-C)

        @test norm((A-B)[1:10,1:10]|>Matrix) < eps()
        @test norm((B-A)[1:10,1:10]|>Matrix) < eps()
        @test norm((A-C)[1:10,1:10]|>Matrix) < eps()
        @test norm((C-A)[1:10,1:10]|>Matrix) < eps()
        @test norm((C-B)[1:10,1:10]|>Matrix) < eps()
        @test norm((B-C)[1:10,1:10]|>Matrix) < eps()
    end

    @testset "Cached" begin
        @test cache(Derivative(Chebyshev(),2))[1,1] == 0

        S=Chebyshev()
        D=Derivative(S)
        @time for padding = [true,false]
          co=ApproxFunBase.CachedOperator(D,ApproxFunBase.RaggedMatrix(Float64[],Int[1],0),(0,0),domainspace(D),rangespace(D),bandwidths(D),padding) #initialise with empty RaggedMatrix
          @test co[1:20,1:10] == D[1:20,1:10]
          @test size(co.data) == (20,10)
          ApproxFunBase.resizedata!(co,10,30)
          @test size(co.data)[2] == 30 && size(co.data)[1] ≥ 20
        end
    end

    @testset "Reverse" begin
        testbandedoperator(ApproxFunBase.Reverse(Chebyshev()))
        testbandedoperator(ApproxFunBase.ReverseOrientation(Chebyshev()))

        @test ApproxFunBase.Reverse(Chebyshev())*Fun(exp) ≈ Fun(x->exp(-x))
        @test ApproxFunBase.ReverseOrientation(Chebyshev())*Fun(exp) ≈ Fun(exp,Segment(1,-1))
    end

    @testset "Sub-operator re-view bug" begin
        D = Derivative(Chebyshev())
        S = view(D[:, 2:end], Block.(3:4), Block.(2:4))
        @test parent(S) == D
        @test parentindices(S) == (3:4,2:4)
        @test bandwidths(S)  == (-2,2)
    end

    @testset "Sub-operators" begin
        f = Fun(exp)
        D = Derivative(Chebyshev())
        testbandedoperator(D[:, 2:end])

        u = D[:,2:end] \ f
        @test u(0.1) ≈ exp(0.1)-coefficient(f,1)

        D̃ = Derivative(space(u))
        @test bandwidths(D̃) == (0,0)
        testbandedoperator(D̃)
        @test norm(u'-f) < 10eps()

        testbandedoperator(D[1:end,2:end])
        u = D[1:end,2:end] \ f
        @test u(0.1) ≈ exp(0.1)-f.coefficients[1]

        testbandedoperator(D[1:∞,2:∞])
        u = D[1:∞,2:∞] \ f
        @test u(0.1) ≈ exp(0.1)-f.coefficients[1]
    end

    @testset "InterlaceOperator" begin
        A = InterlaceOperator(Diagonal([Matrix(I,2,2),Derivative(Chebyshev())]))
        @test blockbandwidths(A) == (0,1)
        @test subblockbandwidths(A) == (2,2)
        @test A[Block(1):Block(2), Block(1):Block(2)] isa BlockBandedMatrix
        @test Matrix(view(A, Block(1), Block(1))) == A[1:3,1:3]
        @test Matrix(view(A, Block(1):Block(2), Block(1):Block(2))) == A[1:4,1:4]
        testblockbandedoperator(A)
    end

    @testset "Projection and subspaces" begin
        S=Chebyshev()
        SS = S|(2:5)
        @test ApproxFunBase.block(SS,3) == Block(4)

        for C in (Operator(I,S)[3:end,:], Operator(I,S)[3:end,1:end])
            @test ApproxFunBase.domaindimension(domainspace(C)) == 1
            @test union(S,domainspace(C)) == S

            B=Dirichlet(S)

            Ai=[B;C]

            @test ApproxFunBase.colstop(Ai,1) == 2

            x=Fun()
            f=exp(x)
            u=[B;C]\[[0.,0.],f]

            @test abs(u(-1)) ≤ 10eps()
            @test abs(u(1)) ≤ 10eps()


            f=(1-x^2)*exp(x)
            u=[B;C]\[[0.,0.],f]

            @test u ≈ f
        end
    end

    @testset "Zero operator has correct bandwidths" begin
        Z=ApproxFunBase.ZeroOperator(Chebyshev())
        @test ApproxFunBase.bandwidths(Z) == ApproxFunBase.bandwidths(Z+Z)
    end

    @testset "hcat of functionals (#407)" begin
        x = Fun()
        B = [1 ldirichlet()]
        @test (B*[1;x])[1] == Fun(ConstantSpace(ApproxFunBase.Point(-1.0)),[0.0])
    end


    @testset "views of views" begin
        A = Derivative(Chebyshev()) + I
        B = A[1:2:∞,1:2:∞]
        C = B[2:∞,3:∞]
        @test A[3:2:∞,5:2:∞] == C
    end

    @testset "Multiplication functions" begin
        x = Fun()
        M = Multiplication(x, Chebyshev())
        @test exp(M).f == Multiplication(exp(x), Chebyshev()).f
        @test (-M).f == Multiplication(-x, Chebyshev()).f
        @test exp(-M).f == Multiplication(exp(-x), Chebyshev()).f
        @test (M/3).f == (3\M).f == Multiplication(x/3, Chebyshev()).f
        @test (M*3).f == (3*M).f == Multiplication(x*3, Chebyshev()).f

        # test for Fun with an empty coefficients vector
        v1 = Fun(Chebyshev(), Float64[])
        v2 = Fun(Chebyshev(), Float64[0.0])
        sp = Ultraspherical(1)
        # the matrix representations should be identical
        @test Multiplication(v1, sp)[1:4, 1:4] == Multiplication(v2, sp)[1:4, 1:4]
    end

    @testset "lastindex" begin
        Z = Operator(I,Chebyshev())
        S = view(Z,1:10,1:10)
        @test lastindex(S,1) == lastindex(S,2) == 10
        @test lastindex(S) == 100
        @test S[end,end] ≈ 1
        @test S[end-1,end] ≈ 0
    end

    @testset "Chebyshev Neumann" begin
        E = Evaluation(Chebyshev(),rightendpoint,1)
        @test E[1:4] == [0,1,4,9]
    end

    @testset "Chebyshev Dirichlet" begin
        S=Chebyshev()
        @time for io in (
                [Dirichlet(S);Derivative(Chebyshev());lneumann(S)],
                [Dirichlet(S);Derivative(Chebyshev())+Fun(cos);lneumann(S)],
                [Dirichlet(S);Derivative(Chebyshev())],
                [Dirichlet(S);Derivative(Chebyshev())+Fun(cos)],
                [Derivative(Chebyshev());Dirichlet(S)],
                [Derivative(Chebyshev())+Fun(cos);Dirichlet(S)])
            testraggedbelowoperator(io)
        end
    end

    @testset "JacobiZ" begin
        testbandedoperator(JacobiZ(Chebyshev(), 0.1))
    end
end


