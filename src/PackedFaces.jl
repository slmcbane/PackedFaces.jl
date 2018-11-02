module PackedFaces

using MirroredArrays

import Base: getindex, setindex!, size
using Base: @pure

export PackingSpec, FaceInterface, FaceTransform, apply_face_transform, PackedFaceArray,
       FaceCode, TOP, RIGHT, LEFT, BOTTOM, @packed_array

include("PackingSpec.jl")

abstract type PackedFaceArray{T, N, SPEC} <: AbstractArray{T, N} end
getindex(A::PackedFaceArray, i::Int) = A.data[i]
setindex!(A::PackedFaceArray, v, i::Int) = (A.data[i] = v)
getindex(A::PackedFaceArray, I::Vararg{Int, N}) where N = A.data[I...]
setindex!(A::PackedFaceArray, v, I::Vararg{Int, N}) where N = (A.data[I...] = v)
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

include("packed_array.jl")

end # module
