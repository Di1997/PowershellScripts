# Parameters Initialization
param(
	[String] $paramName
)

# The code itself
return "Out"

# _GetParams() - wrapper function, containing script name, description, interface, varible descriptions and names
function _GetParams() {
	return @{
		Name = "Script name";
		Description = "Script description";
		IsInterface = $false;
		VarDescriptions = @{
			paramName = @{Name = "Varible name"; Description = "Varible description"};
		};
	}
}