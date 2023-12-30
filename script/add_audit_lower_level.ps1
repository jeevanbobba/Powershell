<#Created on:       ***
Created by:       ***
Organization:     ***
Filename:         ***.ps1
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet #> 

   
$NTFSfolder = "\\SILENTFS01.ent.dir.labor.gov\c$\silnafi_COE_Int_DFS_SILENTFS01_OCIO_SCCM_Library"
get-childitem2 -Recurse $ntfsfolder | Clear-NTFSAudit -Verbose 
get-childitem2 -Recurse $ntfsfolder | Enable-NTFSAuditInheritance -RemoveExplicitAccessRules -PassThru
