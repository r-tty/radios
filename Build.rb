#! /usr/local/bin/ruby

# Initialization
BEGIN {
    COMMANDS = "configure make"
}

# Classes
class Rbuild
    # Intialization
    def initialize
	@command = "make"
	@targets = Array.new
	@targets << "rmk386.rdx"
    end
    
    # Read and parse main configuration file
    def prepare
    end
    
    # Parse command-line arguments
    def parsecmdline(argv)
	cmdgiven = FALSE
	targetgiven = FALSE
    	while opt = argv.shift
	    case opt
	     when "--help", "-h", '-?'
	        printf("Usage: %s [command [target]]\n", $0)
		return nil
	     when /^-/
	        printf("Invalid option '%s'\n", opt)
	        return nil
	     else
		unless cmdgiven
		    @command = opt
		    cmdgiven = TRUE
		else
		    unless targetgiven
			@targets.clear
			targetgiven = TRUE
		    end
		    @targets << opt
		end
	    end
	end
	return TRUE
    end
    
    # Run
    def run
	print @command
	print @targets
    end
    
    # Cleanup
    def cleanup
    end
end

# Main part
begin
    # Instantiate classes
    rbuild = Rbuild.new
    
    # Prepare classes
    rbuild.prepare
    
    # Parse command line
    exit unless rbuild.parsecmdline(ARGV)
    
    # Roll the dice
    rbuild.run    
end
