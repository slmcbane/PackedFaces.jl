module PackedFaces

using MirroredArrays

import Base: getindex, setindex!, size
using Base: @pure, @propagate_inbounds

export PackingSpec, FaceInterface, FaceTransform, apply_face_transform, PackedFaceArray,
       FaceCode, TOP, RIGHT, LEFT, BOTTOM, @packed_array, packing_spec, leftof, rightof

include("PackingSpec.jl")

abstract type PackedFaceArray{T, N, SPEC} <: AbstractArray{T, N} end
@propagate_inbounds getindex(A::PackedFaceArray, i::Int) = A.data[i]
@propagate_inbounds setindex!(A::PackedFaceArray, v, i::Int) = (A.data[i] = v)
@propagate_inbounds getindex(A::PackedFaceArray, I::Vararg{Int, N}) where N = A.data[I...]
@propagate_inbounds setindex!(A::PackedFaceArray, v, I::Vararg{Int, N}) where N = (A.data[I...] = v)
size(A::PackedFaceArray) = size(A.data)

function faces(A::PackedFaceArray{T, DIM, SPEC}) where {T, DIM, SPEC}
    fbs = facebounds(SPEC)
    tfs = transforms(SPEC)
    ( (
       apply_face_transform(
            view(A.data, fbs[i][1], fbs[i][2], (Colon() for j = 3:DIM)...), tfs[i]
       ) for i ∈ 1:nfaces(SPEC)
      )...,
    )
end

@pure packing_spec(::PackedFaceArray{T, DIM, SPEC}) where {T, DIM, SPEC} = SPEC
"""
This implementation is broken under Julia 1.0.2

@pure packing_spec(::Type{ARR}) where ARR <: PackedFaceArray{T, DIM, SPEC} where {T, DIM, SPEC} = SPEC
"""

connectivity(::PackedFaceArray{T, DIM, SPEC}) where {T, DIM, SPEC} = connectivity(SPEC)
function connectivity(::PackedFaceArray{T, DIM, SPEC}, face::Integer) where {T, DIM, SPEC}
    connectivity(SPEC)[face]
end
"""
These implementations also broken.
@pure function connectivity(::Type{ARR}) where ARR <: PackedFaceArray{T, DIM, SPEC} where {T, DIM, SPEC}
    connectivity(SPEC)
end

@pure function connectivity(::Type{ARR}, face::Integer) where ARR <: PackedFaceArray{T, DIM, SPEC} where {T, DIM, SPEC}
    connectivity(SPEC, face)
end
"""

include("packed_array.jl")

end # module
