function default_fmt(T::Type{S}) where {S}
    error("Format for $T is not defined")
end

macro fmt(ex)
    
    msg = "Syntax is: @fmt T = fmtstring"
    @assert(ex.head == :(=), msg)
    @assert(length(ex.args) == 2, msg)
    @assert(ex.args[1] isa Symbol, msg)
    @assert(isa(ex.args[2], String), msg)

    ex1 = ex.args[1]
    ex2 = ex.args[2]
    
    q = quote
        Tables.default_fmt(T::Type{S}) where {S <: $ex1} = $ex2
    end
    return q
end

@fmt Real = "{:.3g}"
@fmt Int  = "{:,n}"
@fmt Bool = "{:}"
@fmt AbstractString = "{:}"

const _fmt_spec_gG = r"[gG]"
const _fmt_spec_g  = r"[g]"
const _fmt_spec_G  = r"[G]"

function fixed_or_scientific(val, format)
    if ismatch(_fmt_spec_gG, format)
        if val isa Integer
            return replace(format, _fmt_spec_gG, "n")
        else
            mag = log(abs(val))/log(10)
            if  (-Inf < mag <= -3) | (mag >= 5)
                r = "e"
            else
                r = "f"
            end
            
            if ismatch(_fmt_spec_g, format)
                return replace(format, _fmt_spec_g, lowercase(r))
            else
                return replace(format, _fmt_spec_G, uppercase(r))
            end
        end
    end
    return format
end

abstract type FormattedNumber{T} end

struct FNum{T} <: FormattedNumber{T}
    val::T
    format::String
    function FNum(val::T, format::String) where T
        return new{T}(val, fixed_or_scientific(val, format))
    end
end


struct FNumSE{T} <: FormattedNumber{T}
    val::T
    se::Float64
    format::String
    format_se::String

    function FNumSE(val::T, se::Float64, format::String,
                    format_se::String) where T
        return new{T}(val, se, fixed_or_scientific(val, format),
                      fixed_or_scientific(se, format_se))
    end
end


function FormattedNumber(val::T, format::String=default_fmt(T)) where T
    return FNum(val, format)
end

function FormattedNumber(val::T, se::S, 
             format::String=default_fmt(T),
             format_se::String=default_fmt(S)) where 
             {T<:AbstractFloat, S <: AbstractFloat}
    se2 = Float64(se) 
    newval, newse = promote(val, se)
    return FNumSE(newval, newse, format, format_se)
end

function FormattedNumber(val::T, se::S,
                         format::String=default_fmt(T),
                         format_se::String=default_fmt(S)) where 
                         {T, S<:AbstractFloat}
    se2 = Float64(se) 
    @assert(isnan(se), "Cannot have non-NaN Standard Errors for $T")
    return FNumSE(val, se, format, format_se)
end

FormattedNumber(x::FormattedNumber) = x


Base.show(io::IO, x::FNum) = print(io, format(x.format, x.val))
Base.show(io::IO, x::FNumSE)= begin
    if isnan(x.se)
        print(io, value(x)) 
    else
        str = string(value(x), " ", se(x))
        print(io, str)
    end
end


Base.convert(::Type{FNumSE}, x::FNum) = FormattedNumber(x.val, NaN)
Base.promote_rule(::Type{FNumSE{T}}, ::Type{FNum{S}}) where {T,S} = FNumSE


value(x::FormattedNumber)   = format(x.format, x.val) 
se(x::FNumSE)               = format("($(x.format_se))", x.se) 
se(x::FNum)                 = ""
