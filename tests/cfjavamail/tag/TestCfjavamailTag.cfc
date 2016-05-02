<cfcomponent displayname="TestInstall"  extends="mxunit.framework.TestCase">

  <cffunction name="setUp" returntype="void" access="public">
		<cfset javamail = createObject("component","cfjavamail.tag.cfjavamail.cfc.JavaMail") />
		<cfset imapsinfo = {protocol:"imaps",port:"3993",username:"to@127.0.0.1",password:"passwrd",mailserver:"127.0.0.1",timeout:3} />
		<cfset greenmail(action="start") />
		<cfset greenmail(action="setUser", email=imapsinfo.username,password=imapsinfo.password) />
		<cftry>
			<cf_javamail action="getFolderInfo"
				folder="INBOX" name="folderInfo"
				protocol="#imapsinfo.protocol#"
				username="#imapsinfo.username#" password="#imapsinfo.password#"
				mailserver="#imapsinfo.mailserver#"
				port="#imapsinfo.port#" timeout="#imapsinfo.timeout#"/>
		<cfcatch>
			<cfif find("is not defined in directory",cfcatch.message)>
				<cfset install = createObject("component","tests.cfjavamail.extension.TestInstall") />
				<cfset install.setUp() />
				<cfset debug(install.testAddJars(false)) />
				<cfset debug(install.testInstallDevCustomTag(false)) />
			<cfelse>
				<cfrethrow />
			</cfif>
		</cfcatch>
		</cftry>

  </cffunction>

  <cffunction name="tearDown" returntype="void" access="public">
		<cfset greenmail(action="stop") />
  </cffunction>

	<cffunction name="dumpvar" access="private">
		<cfargument name="var">
		<cfdump var="#var#">
		<cfabort/>
	</cffunction>

	<cffunction name="testPOP3S">
		<cfscript>
		var protocol="pop3";
		var mailserver="127.0.0.1";
		var port="3995";
		var timeout="3";
		var username=imapsinfo.username;
		var password=imapsinfo.password;
		</cfscript>
		<cf_javamail action="getFolderInfo" protocol="#protocol#" folder="INBOX" name="folderInfo"
			username="#username#" password="#password#" mailserver="#mailserver#"
			port="#port#" timeout="#timeout#"/>
		<cfset request.debug(folderInfo)>
	</cffunction>

	<cffunction name="testIMAPS">
		<cfscript>
			var protocol="imaps";
			var mailserver="imap.gmail.com";
			var port="3993";
			var timeout="3";
			var username=googleinfo.username;
			var password=googleinfo.password;
		</cfscript>
		<cf_javamail action="getFolderInfo" protocol="#protocol#" folder="INBOX" name="folderInfo"
			username="#username#" password="#password#" mailserver="#mailserver#"
			port="#port#" timeout="#timeout#"/>
		<cfset request.debug(folderInfo)>
	</cffunction>

	<cffunction name="testIMAPS">
		<cf_javamail action="getFolderInfo"
			folder="INBOX" name="folderInfo"
			protocol="#imapsinfo.protocol#"
			username="#imapsinfo.username#" password="#imapsinfo.password#"
			mailserver="#imapsinfo.mailserver#"
			port="#imapsinfo.port#" timeout="#imapsinfo.timeout#"/>
		<cfset request.debug(folderInfo)>
	</cffunction>

	<cffunction name="testCopyIMAPStoMSTOR">
		<cfset imapsinfo.action = "getFolder" />
		<cfset imapsinfo.folder = "INBOX" />
		<cfset imapsinfo.name = "imapsFolder" />
		<cf_javamail argumentCollection="#imapsinfo#"/>

		<cfset mstorinfo.action = "getFolder" />
		<cfset mstorinfo.folder = "IMAPSCOPY" />
		<cfset mstorinfo.name = "mstorFolder" />
		<cf_javamail argumentCollection="#mstorinfo#"/>

		<cf_javamail action="copyFolder" sourceFolder="#imapsFolder#" destFolder="#mstorFolder#" maxMessages="5"/>
		<cfset request.debug(cfjavamail) />

	</cffunction>


	<cffunction name="testSearchEmail">

  <!--- action="getall"
   	ATTACHMENTFILES  	ATTACHMENTS  	BODY  	CC  	CIDS  	DATE  	FROM  	HEADER  	HTMLBODY  	MESSAGEID  	MESSAGENUMBER  	REPLYTO  	SUBJECT  	TEXTBODY  	TO  	UID
1

 	CC  	DATE  	FROM  	HEADER  	MESSAGEID  	MESSAGENUMBER  	REPLYTO  	SUBJECT  	TO  	UID
1
--->

	</cffunction>

</cfcomponent>