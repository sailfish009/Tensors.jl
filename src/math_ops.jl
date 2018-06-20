# norm, det, inv, eig, trace, dev
"""
    norm(::Vec)
    norm(::SecondOrderTensor)
    norm(::FourthOrderTensor)

Computes the norm of a tensor.

# Examples
```jldoctest
julia> A = rand(Tensor{2,3})
3×3 Tensor{2,3,Float64,9}:
 0.590845  0.460085  0.200586
 0.766797  0.794026  0.298614
 0.566237  0.854147  0.246837

julia> norm(A)
1.7377443667834922
```
"""
@inline LinearAlgebra.norm(v::Vec) = sqrt(dot(v, v))
@inline LinearAlgebra.norm(S::SecondOrderTensor) = sqrt(dcontract(S, S))

# special case for Tensor{4, 3} since it is faster than unrolling
@inline LinearAlgebra.norm(S::Tensor{4, 3}) = sqrt(mapreduce(abs2, +, S))

@generated function LinearAlgebra.norm(S::FourthOrderTensor{dim}) where {dim}
    idx(i,j,k,l) = compute_index(get_base(S), i, j, k, l)
    ex = Expr[]
    for l in 1:dim, k in 1:dim, j in 1:dim, i in 1:dim
        push!(ex, :(get_data(S)[$(idx(i,j,k,l))]))
    end
    exp = reducer(ex, ex)
    return quote
      $(Expr(:meta, :inline))
      @inbounds return sqrt($exp)
    end
end

"""
    det(::SecondOrderTensor)

Computes the determinant of a second order tensor.

# Examples
```jldoctest
julia> A = rand(SymmetricTensor{2,3})
3×3 SymmetricTensor{2,3,Float64,6}:
 0.590845  0.766797  0.566237
 0.766797  0.460085  0.794026
 0.566237  0.794026  0.854147

julia> det(A)
-0.1005427219925894
```
"""
@inline LinearAlgebra.det(t::SecondOrderTensor{1}) = @inbounds t[1,1]
@inline LinearAlgebra.det(t::SecondOrderTensor{2}) = @inbounds (t[1,1] * t[2,2] - t[1,2] * t[2,1])
@inline function LinearAlgebra.det(t::SecondOrderTensor{3})
    @inbounds (t[1,1] * (t[2,2]*t[3,3] - t[2,3]*t[3,2]) -
                  t[1,2] * (t[2,1]*t[3,3] - t[2,3]*t[3,1]) +
                  t[1,3] * (t[2,1]*t[3,2] - t[2,2]*t[3,1]))
end

"""
    inv(::SecondOrderTensor)

Computes the inverse of a second order tensor.

# Examples
```jldoctest
julia> A = rand(Tensor{2,3})
3×3 Tensor{2,3,Float64,9}:
 0.590845  0.460085  0.200586
 0.766797  0.794026  0.298614
 0.566237  0.854147  0.246837

julia> inv(A)
3×3 Tensor{2,3,Float64,9}:
  19.7146   -19.2802    7.30384
   6.73809  -10.7687    7.55198
 -68.541     81.4917  -38.8361
```
"""
@generated function Base.inv(t::Tensor{2, dim}) where {dim}
    Tt = get_base(t)
    idx(i,j) = compute_index(Tt, i, j)
    if dim == 1
        ex = :($Tt((dinv, )))
    elseif dim == 2
        ex = quote
            v = get_data(t)
            $Tt((v[$(idx(2,2))] * dinv, -v[$(idx(2,1))] * dinv,
                -v[$(idx(1,2))] * dinv,  v[$(idx(1,1))] * dinv))
        end
    else # dim == 3
        ex = quote
            v = get_data(t)
            $Tt(((v[$(idx(2,2))]*v[$(idx(3,3))] - v[$(idx(2,3))]*v[$(idx(3,2))]) * dinv,
                -(v[$(idx(2,1))]*v[$(idx(3,3))] - v[$(idx(2,3))]*v[$(idx(3,1))]) * dinv,
                 (v[$(idx(2,1))]*v[$(idx(3,2))] - v[$(idx(2,2))]*v[$(idx(3,1))]) * dinv,

                -(v[$(idx(1,2))]*v[$(idx(3,3))] - v[$(idx(1,3))]*v[$(idx(3,2))]) * dinv,
                 (v[$(idx(1,1))]*v[$(idx(3,3))] - v[$(idx(1,3))]*v[$(idx(3,1))]) * dinv,
                -(v[$(idx(1,1))]*v[$(idx(3,2))] - v[$(idx(1,2))]*v[$(idx(3,1))]) * dinv,

                 (v[$(idx(1,2))]*v[$(idx(2,3))] - v[$(idx(1,3))]*v[$(idx(2,2))]) * dinv,
                -(v[$(idx(1,1))]*v[$(idx(2,3))] - v[$(idx(1,3))]*v[$(idx(2,1))]) * dinv,
                 (v[$(idx(1,1))]*v[$(idx(2,2))] - v[$(idx(1,2))]*v[$(idx(2,1))]) * dinv))
        end
    end
    return quote
        $(Expr(:meta, :inline))
        dinv = 1 / det(t)
        @inbounds return $ex
    end
end

@generated function Base.inv(t::SymmetricTensor{2, dim}) where {dim}
    Tt = get_base(t)
    idx(i,j) = compute_index(Tt, i, j)
    if dim == 1
        ex = :($Tt((dinv, )))
    elseif dim == 2
        ex = quote
            v = get_data(t)
            $Tt((v[$(idx(2,2))] * dinv, -v[$(idx(2,1))] * dinv,
                 v[$(idx(1,1))] * dinv))
        end
    else # dim == 3
        ex = quote
            v = get_data(t)
            $Tt(((v[$(idx(2,2))]*v[$(idx(3,3))] - v[$(idx(2,3))]*v[$(idx(3,2))]) * dinv,
                -(v[$(idx(2,1))]*v[$(idx(3,3))] - v[$(idx(2,3))]*v[$(idx(3,1))]) * dinv,
                 (v[$(idx(2,1))]*v[$(idx(3,2))] - v[$(idx(2,2))]*v[$(idx(3,1))]) * dinv,

                 (v[$(idx(1,1))]*v[$(idx(3,3))] - v[$(idx(1,3))]*v[$(idx(3,1))]) * dinv,
                -(v[$(idx(1,1))]*v[$(idx(3,2))] - v[$(idx(1,2))]*v[$(idx(3,1))]) * dinv,

                 (v[$(idx(1,1))]*v[$(idx(2,2))] - v[$(idx(1,2))]*v[$(idx(2,1))]) * dinv))
        end
    end
    return quote
        $(Expr(:meta, :inline))
        dinv = 1 / det(t)
        @inbounds return $ex
    end
end

function Base.inv(t::Tensor{4, dim}) where {dim}
    fromvoigt(Tensor{4, dim}, inv(tovoigt(t)))
end

function Base.inv(t::SymmetricTensor{4, dim, T}) where {dim, T}
    frommandel(SymmetricTensor{4, dim}, inv(tomandel(t)))
end

Base.:\(S1::SecondOrderTensor, S2::AbstractTensor) = inv(S1) ⋅ S2

"""
    eigvals(::SymmetricTensor{2})

Compute the eigenvalues of a symmetric second order tensor.
"""
@inline LinearAlgebra.eigvals(S::SymmetricTensor) = (E = eigen(S); E.values)

"""
    eigvecs(::SymmetricTensor{2})

Compute the eigenvectors of a symmetric second order tensor.
"""
@inline LinearAlgebra.eigvecs(S::SymmetricTensor) = (E = eigen(S); E.vectors)

struct Eigen{T, dim, M}
    values::Vec{dim, T}
    vectors::Tensor{2, dim, T, M}
end

# destructure via iteration
Base.iterate(E::Eigen, state::Int=1) = iterate((E.values, E.vectors), state)

"""
    eigen(A::SymmetricTensor{2})

Compute the eigenvalues and eigenvectors of a symmetric second order tensor
and return an `Eigen` object. The eigenvalues are stored in a `Vec`,
sorted in ascending order. The corresponding eigenvectors are stored
as the columns of a `Tensor`.

See [`eigvals`](@ref) and [`eigvecs`](@ref).

# Examples
```jldoctest
julia> A = rand(SymmetricTensor{2, 2});

julia> E = eigen(A)
Tensors.Eigen{Float64,2,4}([-0.188355, 1.34544], [-0.701412 0.712756; 0.712756 0.701412])

julia> E.values
2-element Tensor{1,2,Float64,2}:
 -0.1883547111127678
  1.345436766284664

julia> E.vectors
2×2 Tensor{2,2,Float64,4}:
 -0.701412  0.712756
  0.712756  0.701412
```
"""
LinearAlgebra.eigen

"""
    eigvals(::Eigen)

Extract eigenvalues from an `Eigen` object, returned by [`eigen`](@ref).
"""
@inline LinearAlgebra.eigvals(E::Eigen) = E.values
"""
    eigvecs(::Eigen)

Extract eigenvectors from an `Eigen` object, returned by [`eigen`](@ref).
"""
@inline LinearAlgebra.eigvecs(E::Eigen) = E.vectors

"""
    sqrt(S::SymmetricTensor{2})

Calculate the square root of the positive definite symmetric
second order tensor `S`, such that `√S ⋅ √S == S`.

# Examples
```jldoctest
julia> S = rand(SymmetricTensor{2,2}); S = tdot(S)
2×2 SymmetricTensor{2,2,Float64,3}:
 0.937075  0.887247
 0.887247  0.908603

julia> sqrt(S)
2×2 SymmetricTensor{2,2,Float64,3}:
 0.776178  0.578467
 0.578467  0.757614

julia> √S ⋅ √S ≈ S
true
```
"""
Base.sqrt(::SymmetricTensor{2})

Base.sqrt(S::SymmetricTensor{2,1}) = SymmetricTensor{2,1}((sqrt(S[1,1]),))

# https://en.m.wikipedia.org/wiki/Square_root_of_a_2_by_2_matrix
function Base.sqrt(S::SymmetricTensor{2,2})
    s = √(det(S))
    t = √(tr(S)+2s)
    return SymmetricTensor{2,2}((S[1,1]+s, S[2,1], S[2,2]+s)) / t
end

function Base.sqrt(S::SymmetricTensor{2,3,T}) where T
    E = eigen(S)
    λ = E.values
    Φ = E.vectors
    z = zero(T)
    Λ = Tensor{2,3}((√(λ[1]), z, z, z, √(λ[2]), z, z, z, √(λ[3])))
    return symmetric(Φ⋅Λ⋅Φ')
end

"""
    tr(::SecondOrderTensor)

Computes the trace of a second order tensor.

# Examples
```jldoctest
julia> A = rand(SymmetricTensor{2,3})
3×3 SymmetricTensor{2,3,Float64,6}:
 0.590845  0.766797  0.566237
 0.766797  0.460085  0.794026
 0.566237  0.794026  0.854147

julia> tr(A)
1.9050765715072775
```
"""
@generated function LinearAlgebra.tr(S::SecondOrderTensor{dim}) where {dim}
    idx(i,j) = compute_index(get_base(S), i, j)
    ex = Expr[:(get_data(S)[$(idx(i,i))]) for i in 1:dim]
    exp = reduce((ex1, ex2) -> :(+($ex1, $ex2)), ex)
    @inbounds return exp
end

Base.mean(S::SecondOrderTensor) = tr(S) / 3

"""
    vol(::SecondOrderTensor)

Computes the volumetric part of a second order tensor
based on the additive decomposition.

# Examples
```jldoctest
julia> A = rand(SymmetricTensor{2,3})
3×3 SymmetricTensor{2,3,Float64,6}:
 0.590845  0.766797  0.566237
 0.766797  0.460085  0.794026
 0.566237  0.794026  0.854147

julia> vol(A)
3×3 SymmetricTensor{2,3,Float64,6}:
 0.635026  0.0       0.0
 0.0       0.635026  0.0
 0.0       0.0       0.635026

julia> vol(A) + dev(A) ≈ A
true
```
"""
vol(S::SecondOrderTensor) = mean(S) * one(S)

"""
    dev(::SecondOrderTensor)

Computes the deviatoric part of a second order tensor.

# Examples
```jldoctest
julia> A = rand(Tensor{2, 3});

julia> dev(A)
3×3 Tensor{2,3,Float64,9}:
 0.0469421  0.460085   0.200586
 0.766797   0.250123   0.298614
 0.566237   0.854147  -0.297065

julia> tr(dev(A))
0.0
```
"""
@inline function dev(S::SecondOrderTensor)
    Tt = get_base(typeof(S))
    trace = tr(S) / 3
    Tt(
        @inline function(i, j)
            @inbounds  v = i == j ? S[i,j] - trace : S[i,j]
            v
        end
    )
end

# http://inside.mines.edu/fs_home/gmurray/ArbitraryAxisRotation/
"""
    rotate(x::Vec{3}, u::Vec{3}, θ::Number)

Rotate a three dimensional vector `x` around another vector `u` a total of `θ` radians.

# Examples
```jldoctest
julia> x = Vec{3}((0.0, 0.0, 1.0))
3-element Tensor{1,3,Float64,3}:
 0.0
 0.0
 1.0

julia> u = Vec{3}((0.0, 1.0, 0.0))
3-element Tensor{1,3,Float64,3}:
 0.0
 1.0
 0.0

julia> rotate(x, u, π/2)
3-element Tensor{1,3,Float64,3}:
 1.0
 0.0
 6.123233995736766e-17
```
"""
function rotate(x::Vec{3}, u::Vec{3}, θ::Number)
    ux = u ⋅ x
    u² = u ⋅ u
    c = cos(θ)
    s = sin(θ)
    (u * ux * (1 - c) + u² * x * c + sqrt(u²) * (u × x) * s) / u²
end

