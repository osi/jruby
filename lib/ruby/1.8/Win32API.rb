require 'rbconfig'
raise  LoadError.new("Win32API only supported on win32") unless Config::CONFIG['host_os'] =~ /mswin/

require 'ffi-internal.so'

class Win32API
  CONVENTION = FFI::Platform.windows? ? :stdcall : :default
  SUFFIXES = $KCODE == 'UTF8' ? [ '', 'W', 'A' ] : [ '', 'A', 'W' ]
  TypeDefs = {
    'V' => FFI::Type::VOID,
    'P' => FFI::Type::POINTER,
    'I' => FFI::Type::INT,
    'N' => FFI::Type::INT,
    'L' => FFI::Type::INT,
  }

  def self.find_type(name)
    code = TypeDefs[name]
    raise TypeError, "Unable to resolve type '#{name}'" unless code
    return code
  end

  def self.map_types(spec)
    if spec.kind_of?(String)
      spec.split //
    elsif spec.kind_of?(Array)
      spec
    else
      raise ArgumentError.new("invalid parameter types specification")
    end.map { |c| self.find_type(c) }
  end

  def self.map_library_name(lib)
    # Mangle the library name to reflect the native library naming conventions
    if lib && File.basename(lib) == lib
      ext = ".#{FFI::Platform::LIBSUFFIX}"
      lib = FFI::Platform::LIBPREFIX + lib unless lib =~ /^#{FFI::Platform::LIBPREFIX}/
      lib += ext unless lib =~ /#{ext}/
    end
    lib
  end
  
  def initialize(lib, func, params, ret='L')
    @lib = lib
    @func = func
    @params = params
    @return = ret

    #
    # Attach the method as 'call', so it gets all the froody arity-splitting optimizations
    #
    @lib = FFI::DynamicLibrary.open(Win32API.map_library_name(lib), FFI::DynamicLibrary::RTLD_LAZY | FFI::DynamicLibrary::RTLD_GLOBAL)
    SUFFIXES.each do |suffix|
      sym = @lib.find_function(func.to_s + suffix)
      if sym
        @ffi_func = FFI::Function.new(Win32API.find_type(ret), Win32API.map_types(params), sym)
        @ffi_func.attach(self, :call)
        self.instance_eval("alias :Call :call")
        break
      end
    end
    
    raise FFI::NotFoundError, "Could not locate #{func}" unless @ffi_func
  end

  def inspect
    params = []
    if @params.kind_of?(String)
      @params.each_byte { |c| params << TypeDefs[c.chr] }
    else
      params = @params.map { |p| TypeDefs[p]}
    end
    "#<Win32API::#{@func} library=#{@lib} function=#{@func} parameters=[ #{params.join(',')} ], return=#{Win32API.find_type(@return)}>"
  end
end