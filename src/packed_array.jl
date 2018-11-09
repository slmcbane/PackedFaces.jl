const packed_array_args = Set(
    [:xybounds, :facebounds, :transforms, :interfaces, :nfaces]
)

macro packed_array(tp_name::Symbol, args...)
    args_received = Dict{Symbol, Any}()

    for ex in args
        if !(isassignment(ex))
            throw(ErrorException("@packed_array expects a list of keyword assignments"))
        end

        sym = ex.args[1]
        if !(sym isa Symbol)
            throw(ErrorException("@packed_array expects a list of keyword assignments"))
        elseif !(sym ∈ packed_array_args)
            throw(ErrorException("Unrecognized keyword argument to @packed_array: $sym"))
        elseif haskey(args_received, sym)
            throw(ErrorException("Multiple specification of keyword $sym"))
        end

        args_received[sym] = ex.args[2]
    end

    if !(keys(args_received) == packed_array_args)
        throw(ErrorException("Did not receive a specification for all required arguments"))
    end

    quote
        let SPEC = PackingSpec(
            nfaces = $(esc(args_received[:nfaces])),
            xybounds = $(esc(args_received[:xybounds])),
            facebounds = $(esc(args_received[:facebounds])),
            transforms = $(esc(args_received[:transforms])),
            interfaces = $(esc(args_received[:interfaces]))
           )
            struct $(tp_name){T, N, ARR} <: PackedFaceArray{T, N, SPEC}
                data::ARR

                function $(tp_name)(A::AbstractArray{T, N}) where {T, N}
                    @assert size(A)[1:2] === xybounds(SPEC)
                    new{T, N, typeof(A)}(A)
                end
            end
        end
    end
end

isassignment(ex) = (ex.head === :(=))
