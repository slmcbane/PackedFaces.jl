@enum FaceCode TOP RIGHT LEFT BOTTOM

function rightof(c::FaceCode)
    if c === TOP
        RIGHT
    elseif c === RIGHT
        BOTTOM
    elseif c === BOTTOM
        LEFT
    else
        TOP
    end
end

function leftof(c::FaceCode)
    if c === TOP
        LEFT
    elseif c === LEFT
        BOTTOM
    elseif c === BOTTOM
        RIGHT
    else
        TOP
    end
end

"""
Synopsis
--------
```
FaceInterface(faces::Pair{Int, Int}, which::Integer,
              ranges::Tuple{UnitRange{Int}, UnitRange{Int}})
```
`faces`: A pair giving the indices (1-based) of the two faces who are interfaced.

`which`: A pair of `FaceCode`s giving the side of each face that contains the interface,
in respective order. This is necessary to handle the cases at the arctic and antarctic in
my application; the "top" of the arctic face, which has no natural orientation, will
interface to the top of another face no matter how it is arranged.

`ranges`: A pair of `OrdinalRange`s giving the range of indices on each face that make
up the interface. The element at `ranges[1][1]` on the first face of the interface pairs
with the element at `ranges[2][1]` on the second face, etc.

The constructed object stores no data; the interface information is encoded in the type.
"""
struct FaceInterface{FACES, WHICH, RANGES}
    function FaceInterface(faces::Pair{Int, Int}, which::Pair{FaceCode, FaceCode},
                           ranges::Pair{R1, R2}) where R1 <: OrdinalRange{Int,Int} where R2 <: OrdinalRange{Int,Int}
        @assert faces[1] > 0 && faces[2] > 0
        @assert length(ranges[1]) == length(ranges[2])
        new{faces, which, ranges}()
    end
end

@pure faces(::FaceInterface{FACES}) where FACES = FACES
function swapfaces(::FaceInterface{FACES, WHICH, RANGES}) where {FACES, WHICH, RANGES}
    FaceInterface(FACES[2] => FACES[1], WHICH[2] => WHICH[1], RANGES[2] => RANGES[1])
end

struct FaceTransform{ROTATE, TRANSPOSE}
    function FaceTransform(; rotations::Int = 0, transpose::Bool = false)
        rotations = (rotations % 4 + 4 * (sign(rotations) == -1)) % 4
        new{rotations, transpose}()
    end
end

struct PackingSpec{M, N, NFACES, FACEBOUNDS, TRANSFORMS, INTERFACES}
    function PackingSpec(; nfaces::Int,
                           xybounds::Tuple{Int, Int},
                           facebounds::NTuple{NFACES, Tuple{UnitRange{Int},UnitRange{Int}}},
                           transforms::NTuple{NFACES, FaceTransform},
                           interfaces::NTuple{NI, FaceInterface}
                        ) where {NFACES, NI}
        @assert nfaces === NFACES "Number of face specifications != given nfaces"
        M, N = xybounds
        @assert M > 0 && N > 0 "Why are you using this module?"

        # Ensures that faces specified are an exact cover of (1, M) × (1, N)
        check_face_bounds(M, N, facebounds)
        NI != 0 && check_interfaces(facebounds, transforms, interfaces)
        new{M, N, NFACES, facebounds, transforms, interfaces}()
    end
end

@pure nfaces(::PackingSpec{M, N, NFACES}) where {M, N, NFACES} = NFACES
@pure facebounds(::PackingSpec{M, N, NF, FB}) where {M, N, NF, FB} = FB
@pure xybounds(::PackingSpec{M, N}) where {M, N} = (M, N)
@pure transforms(::PackingSpec{M, N, NF, FB, TR}) where {M, N, NF, FB, TR} = TR
@pure interfaces(::PackingSpec{M, N, NF, FB, T, I}) where {M, N, NF, FB, T, I} = I

function apply_face_transform(A::AbstractArray{T, N}, ::FaceTransform{ROTATE, TRANSPOSE}
                             ) where {T, N, ROTATE, TRANSPOSE}
    @assert ROTATE ∈ (0, 1, 2, 3)

    rotate(A) = MirroredArray(transpose(A), 2)
    if TRANSPOSE
        if ROTATE == 0
            PermutedDimsArray(A, (2, 1, 3:N...,))
        elseif ROTATE == 1
            MirroredArray(A, 1)
        elseif ROTATE == 2
            PermutedDimsArray(MirroredArray(A, 1, 2), (2, 1, 3:N...,))
        else # ROTATE == 3
            MirroredArray(A, 2)
        end
    else
        if ROTATE == 0
            A
        elseif ROTATE == 1
            MirroredArray(PermutedDimsArray(A, (2, 1, 3:N...,)), 2)
        elseif ROTATE == 2
            MirroredArray(A, 1, 2)
        else # ROTATE == 3
            PermutedDimsArray(MirroredArray(A, 2), (2, 1, 3:N...,))
        end
    end
end

# @TODO this is not a complete implementation; a set of faces that is not an exact cover
# can still pass this test.
function check_face_bounds(M, N, bounds::NTuple{NFACES, Tuple{UnitRange{Int},UnitRange{Int}}}
                          ) where NFACES
    for i ∈ 1:NFACES
        @assert bounds[i][1][1] < bounds[i][1][end]
        @assert bounds[i][2][1] < bounds[i][2][end]
        for j ∈ i+1:NFACES
            # Checks that the two faces specified by these two sets of bounds do
            # not overlap.
            test_bounds_intersection(bounds[i], bounds[j])
        end
        # Make sure the range of first-dimension indices is within the range of M
        @assert bounds[i][1][1] >= 1 && bounds[i][1][2] <= M
        # Make sure the range of second-dimension indices is with the range of N
        @assert bounds[i][2][1] >= 1 && bounds[i][2][2] <= N
    end

    # Checks that all indices in M and N are covered.
    sorted = sort(collect(bounds), by=t->t[1][1])
    @assert sorted[1][1][1] == 1 && sorted[end][1][end] == M
    for i ∈ 1:NFACES-1
        @assert sorted[i][1][end] >= sorted[i+1][1][1] - 1
    end

    sorted = sort(collect(bounds), by=t->t[2][1])
    @assert sorted[1][2][1] == 1 && sorted[end][2][end] == N
    for i ∈ 1:NFACES-1
        @assert sorted[i][2][end] >= sorted[i+1][2][1] - 1
    end
end

function test_bounds_intersection(b1, b2)
    if b1[1][1] <= b2[1][end]
        if b2[1][1] <= b1[1][end]
            @assert b1[2][1] > b2[2][end] || b2[2][1] > b1[2][end]
        end
    end
end

function check_interfaces(bounds::NTuple{NFACES, Tuple{UnitRange{Int},UnitRange{Int}}},
                          transforms::NTuple{NFACES, FaceTransform},
                          interfaces::NTuple{NI, FaceInterface}
                         ) where {NFACES, NI}
    for interface ∈ interfaces
        check_interface(interface, bounds, transforms)
    end
end

function check_interface(::FaceInterface{FACES, WHICH, RANGES},
                         bounds::NTuple{NFACES, Tuple{UnitRange{Int},UnitRange{Int}}},
                         transforms::NTuple{NFACES, FaceTransform}
                        ) where {FACES, WHICH, RANGES, NFACES}
    @assert FACES[1] <= NFACES && FACES[2] <= NFACES

    A = apply_face_transform(CartesianIndices(bounds[FACES[1]]), transforms[FACES[1]])
    B = apply_face_transform(CartesianIndices(bounds[FACES[2]]), transforms[FACES[2]])

    extr = (extrema(RANGES[1]), extrema(RANGES[2]))

    @assert extr[1][1] >= 1 && extr[2][1] >= 1
    
    if WHICH[1] ∈ (TOP, BOTTOM)
        @assert extr[1][2] <= size(A, 2)
    else
        @assert extr[1][2] <= size(A, 1)
    end

    if WHICH[2] ∈ (TOP, BOTTOM)
        @assert extr[2][2] <= size(B, 2)
    else
        @assert extr[2][2] <= size(B, 1)
    end
end

@generated function face_connectivity(::Val{interfaces}, ::Val{N}) where {interfaces, N}
    connect = (i for i ∈ interfaces if N ∈ faces(i))
    connect = (N == faces(i)[2] ? swapfaces(i) : i for i ∈ connect)
    :($((connect...,)))
end

function connectivity(::Val{interfaces}, ::Val{NFACE}) where {interfaces, NFACE}
    if NFACE > 0
        (face_connectivity(Val(interfaces), Val(NFACE)),
         connectivity(Val(interfaces), Val(NFACE-1))...,)
    else
        ()
    end
end

function connectivity(::PackingSpec{M, N, NF, FB, T, I}) where {M, N, NF, FB, T, I}
    connectivity(Val(I), Val(NF)) |> reverse
end

@propagate_inbounds function connectivity(s::PackingSpec{M, N, NF, FB, T, I},
                                          face::Integer) where {M, N, NF, FB, T, I}
    connectivity(s)[face]
end

