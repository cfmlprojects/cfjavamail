<cfcomponent>

	<cfset this.metadata.attributetype="mixed">
  <cfset this.metadata.attributes={
	action:			{required:true,type:"string"},
	protocol:			{required:true,type:"string"},
	useTLS:			{required:false,type:"boolean",default:false},
	useSSL:			{required:false,type:"boolean",default:false},
	allowFallback:			{required:false,type:"boolean",default:true},
	username:			{required:true,type:"string"},
	password:			{required:true,type:"string"},
	mailserver:			{required:true,type:"string"},
	port:			{required:true,type:"numeric",default:0},
	timeout:			{required:true,type:"string"},
	folder:			{required:false,type:"string",default:""},
	sourceFolder:			{required:false,type:"string"},
	destFolder:			{required:false,type:"string"},
	newFolder:			{required:false,type:"string"},
	recurse:			{required:false,type:"boolean"},
	renameTo:			{required:false,type:"string"},
	value:			{required:false,type:"boolean"},
	messageNumber:			{required:false,type:"string"},
	messageId:			{required:false,type:"string"},
	text:			{required:false,type:"string"},
	startMessageNumber:			{required:false,type:"numeric"},
	maxMessages:			{required:false,type:"numeric",default:500},
	messageCount:			{required:false,type:"numeric"},
	name:			{required:false,type:"string",default:"cfjavamail"},

	to:			{required:false,type:"string"},
	cc:			{required:false,type:"string"},
	bcc:			{required:false,type:"string"},
	subject:			{required:false,type:"string"},
	body:			{required:false,type:"string"},
	attachments:			{required:false,type:"string"},

	Attach:			{required:false,type:"string"},
	includeData:			{required:false,type:"string"}

	}/>

  <cfset _log = [] />
  <!--- no need to recreate these every time, only using them for static vars and methods --->
  <cfset variables.FolderClass = createObject("java","javax.mail.Folder")>
  <cfset variables.mimeUtil = createObject("java","javax.mail.internet.MimeUtility")>
  <cfset variables.objFlag = CreateObject("Java", "javax.mail.Flags$Flag")>
  <cfset variables.objRecipientType = CreateObject("Java", "javax.mail.Message$RecipientType")>
  <cfset variables.fProfileItem = createObject("java","javax.mail.UIDFolder$FetchProfileItem")>
  <cfset variables.fMessageIDTerm = createObject("java","javax.mail.search.MessageIDTerm")>
  <cfset variables.fFlags = CreateObject("Java", "javax.mail.Flags$Flag")>

  <cfset variables.byteArray = repeatString(" ", 1000).getBytes()>
  <cfset variables.showTextHtmlAttachmentsInline = false>
  <!--- this is set here because I'm too lazy right now to figure
        out how to get it to work properly in the recursive function
        GetFolderStructure() and folderList()
        --->
  <cfset variables.sortOrder = 0>

  <cffunction name="onEndTag" output="yes" returntype="boolean">
 		<cfargument name="attributes" type="struct">
 		<cfargument name="caller" type="struct">
 		<cfargument name="generatedContent" type="string">
		<cfreturn false/>
	</cffunction>

		<cffunction name="dumpvar">
		  <cfargument name="var" default="blank">
		  <cfargument name="abort" default="true">
		  <cftry>
			  <cfdump var="#var#">
			<cfcatch>
			  <cfset writeoutput(cfcatch.Message & " " & cfcatch.Detail & " " & cfcatch.TagContext[1].line & " " & cfcatch.stacktrace) />
			</cfcatch>
			</cftry>
			<cfif arguments.abort>
			  <cfabort />
			</cfif>
		</cffunction>

	<cffunction name="sessionEnabled" returntype="boolean" access="private">
		<cftry>
			<cfset session.blah = "woohoo" />
			<cfset structDelete(session,"blah") />
			<cfreturn true />
		<cfcatch>
			<cfreturn false />
		</cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="runAction">
		<cfargument name="args" required="true" />
		<cfif !listFindNoCase("copyFolder,moveToFolder,syncFolder",args.action)>
			<cfset _init(argumentCollection = args) />
		</cfif>
		<cfscript>
			var runFunk = this[args.action];
			var results = runFunk(argumentCollection=args);
			return results;
		</cfscript>
	</cffunction>

    <cffunction name="init" output="no" returntype="void" hint="invoked after tag is constructed">
         <cfargument name="hasEndTag" type="boolean" required="yes" />
         <cfargument name="parent" type="component" required="no" hint="the parent cfc custom tag, if there is one" />
         <cfset variables.hasEndTag = arguments.hasEndTag />
    </cffunction>

    <cffunction name="_init" access="public" output="No" returnType="boolean"
         hint="Initialize this component and open a connection.">
         <cfargument name="protocol" type="string" required="Yes" />
         <cfargument name="username" type="string" required="Yes" />
         <cfargument name="password" type="string" required="Yes" />
         <cfargument name="mailServer" type="string" required="Yes" />
         <cfargument name="port" type="numeric" default="0" />
         <cfargument name="timeout" type="numeric" required="No" default="60" />
         <cfargument name="useTLS" type="boolean" default="false" />
         <cfargument name="useSSL" type="boolean" default="false" />
         <cfargument name="allowFallback" type="boolean" default="true" />
         <cfset var connectionhash = hash(username & mailServer & port)>
         <cfif sessionEnabled()>
              <cfif structKeyExists(session,"_cfjavamail_#connectionhash#")>
                   <cfset variables._instance = session["_cfjavamail_#connectionhash#"] />
                   <cfset session["_cfjavamail_#connectionhash#"] = variables._instance />
              <cfelse>
                   <cfset variables._instance = structNew() />
                   <cfset session["_cfjavamail_#connectionhash#"] = variables._instance />
              </cfif>
         <cfelse>
              <cfif structKeyExists(request,"_cfjavamail_#connectionhash#")>
                   <cfset variables._instance = request["_cfjavamail_#connectionhash#"] />
                   <cfset request["_cfjavamail_#connectionhash#"] = variables._instance />
              <cfelse>
                   <cfset variables._instance = structNew() />
                   <cfset request["_cfjavamail_#connectionhash#"] = variables._instance />
              </cfif>
         </cfif>

         <cfset variables._instance.username = arguments.username />
         <cfset variables._instance.password = arguments.password />
         <cfset variables._instance.mailServer = trim(arguments.mailServer) />
         <cfset variables._instance.protocol = lcase(trim(arguments.protocol)) />
         <cfset variables._instance.useTLS = arguments.useTLS />
         <cfset variables._instance.useSSL = arguments.useSSL />
         <cfset variables._instance.allowFallback = arguments.allowFallback />
         <cfset variables._instance.mailServerPort = val(arguments.port) />
         <cfset variables._instance.protocolTimeout = trim(arguments.timeout * 1000) />
         <cfset variables._instance.connectionhash = connectionhash />
         <cfset getConnectedMailStore() />
         <cfif arguments.protocol neq "smtp">
              <cfreturn variables._instance.connection.isConnected() />
         <cfelse>
              <cfreturn true />
         </cfif>
    </cffunction>

    <cffunction name="onStartTag" output="yes" returntype="boolean">
   		<cfargument name="attributes" type="struct">
	   		<cfargument name="caller" type="struct">
			<cfif structKeyExists(attributes,"argumentCollection")>
				<cfset attributes = attributes.argumentCollection />
			</cfif>
			<cfif !listFindNoCase("copyFolder,moveToFolder,syncFolder",attributes.action)>
				<cfset _init(argumentCollection = attributes) />
			</cfif>
			<cfscript>
				var runFunk = this[attributes.action];
				var results = runFunk(argumentCollection=attributes);
				caller[attributes.name] = results;
			</cfscript>
			<cfif not variables.hasEndTag>
				<cfset onEndTag(attributes,caller,"") />
			</cfif>
	    <cfreturn variables.hasEndTag>
		</cffunction>

    <cffunction name="getFolderInfo" access="public" output="No" returntype="Struct"
        hint="Get information about a specific folder.">
        <cfargument name="folder" required="Yes" type="string">
        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = "">
        <Cfset var folderInfo = structNew()>
        <cftry>
            <cfset objFolder = OpenFolder(objStore, arguments.folder)>
            <cfset folderInfo.fullName = objFolder.getFullName()>
            <cfset folderInfo.name = objFolder.getName()>
            <cfset folderInfo.type = objFolder.getType()>
            <cfset folderInfo.exists = objFolder.exists()>
            <cfif folderInfo.type eq objFolder.HOLDS_FOLDERS>
                <cfset folderInfo.messageCount = 0>
                <cfset folderInfo.deletedMessageCount = 0>
                <cfset folderInfo.newMessageCount = 0>
                <cfset folderInfo.unreadMessageCount = 0>
                <cfset folderInfo.hasNewMessages = 0>
            <cfelse>
                <cfset folderInfo.messageCount = objFolder.getMessageCount()>
                <cfset folderInfo.deletedMessageCount = objFolder.getDeletedMessageCount()>
                <cfset folderInfo.newMessageCount = objFolder.getNewMessageCount()>
                <cfset folderInfo.unreadMessageCount = objFolder.getUnreadMessageCount()>
                <cfset folderInfo.hasNewMessages = objFolder.hasNewMessages()>
            </cfif>
            <cfset objFolder.close(false)>
            <cfcatch type="any">
				<cfif cfcatch.type == "javax.mail.FolderNotFoundException">
	                <cfset folderInfo.exists = false>
                <cfelse>
	                <cfset folderInfo.exists = "unknown">
				</cfif>
                <cfset folderInfo.fullName = arguments.folder>
                <cfset folderInfo.name = arguments.folder>
                <cfset folderInfo.messageCount = 0>
                <cfset folderInfo.deletedMessageCount = 0>
                <cfset folderInfo.newMessageCount = 0>
                <cfset folderInfo.unreadMessageCount = 0>
                <cfset folderInfo.hasNewMessages = false>
            </cfcatch>
        </cftry>
        <cfreturn folderInfo>
    </cffunction>

    <cffunction name="getFolder" access="public" output="No" returntype="object"
        hint="Get information about a specific folder.">
        <cfargument name="folder" required="Yes" type="string">
        <cfset var objStore = getConnectedMailStore()>
		<cfreturn objStore.getDefaultFolder().getFolder(arguments.Folder) />
    </cffunction>

    <cffunction name="copyFolder" access="public" output="No" returntype="Array"
        hint="Get information about a specific folder.">
        <cfargument name="sourceFolder" required="Yes" type="object">
        <cfargument name="destFolder" required="Yes" type="object">
        <cfargument name="maxMessages" default="9999">
		<cfscript>
			var folder = variables.FolderClass;
			var info = [];
			var msgCnt = 0;
			var df = destFolder;
			sourceFolder.open(Folder.READ_ONLY);
			if (!destFolder.exists()) {
	            destFolder.create(Folder.HOLDS_MESSAGES);
	        }
	        destFolder.open(Folder.READ_WRITE);
	        arrayAppend(info,"Getting messages in destination store");
            var messages = sourceFolder.getMessages();
            //sourceFolder.copyMessages(messages,df);
	        arrayAppend(info,"Copying #maxMessages# of " & arrayLen(messages) & " messages");
	        for (message in messages) {
				var messageId = getMessageId(message);
				var mSearch = getMessageById(df,messageId);
				if (arrayLen(mSearch) == 1) {
	        		arrayAppend(info,"skipping #messageId# as it is already in the store");
				    continue;
				}
	            if(msgCnt >= maxMessages) {
	            	break;
	            }
	        	msgCnt++;
	            sourceFolder.copyMessages([message],df);
	        	arrayAppend(info,"Synced message #message.getMessageId()# #message.getSubject()#");
	        }
	        sourceFolder.close(false);
	        arrayAppend(info,"Synced messages.  Source had #arrayLen(messages)#, dest has #arrayLen(destFolder.getMessages())#");
	        destFolder.close(false);
	        return info;
		</cfscript>
    </cffunction>

    <cffunction name="moveToFolder" access="public" output="No" returntype="Array"
        hint="Get information about a specific folder.">
        <cfargument name="sourceFolder" required="Yes" type="object">
        <cfargument name="destFolder" required="Yes" type="object">
        <cfargument name="maxMessages" default="9999">
		<cfscript>
			var folder = variables.FolderClass;
			var info = [];
			var msgCnt = 0;
			sourceFolder.open(Folder.READ_WRITE);
			if (!destFolder.exists()) {
	        	arrayAppend(info,"Creating destination folder: " & destFolder.getName());
	            destFolder.create(Folder.HOLDS_MESSAGES);
	        }
	        destFolder.open(Folder.READ_WRITE);
	        arrayAppend(info,"Getting messages from source folder");
            var messages = sourceFolder.getMessages();
            //sourceFolder.copyMessages(messages,df);
            if(arrayLen(messages) < maxMessages) {
            	maxMessages = arrayLen(messages);
            }
	        arrayAppend(info,"Moving #maxMessages# of " & arrayLen(messages) & " messages");
	        for (message in messages) {
	            if(msgCnt > maxMessages) {
	            	break;
	            }
				var messageId = getMessageId(message);
				var mSearch = getMessageById(destFolder,messageId);
				if (arrayLen(mSearch) == 1) {
	        		arrayAppend(info,"deleting #messageId# as it is already in the store");
	            	message.setFlag(fFlags["DELETED"],true);
//	            	setFlag(sf, message.getMessageNumber(), "DELETED", true);
				    continue;
				}
	            sourceFolder.copyMessages([message],destFolder);
	            message.setFlag(fFlags["DELETED"],true);
	        	arrayAppend(info,"Moved message #message.getMessageId()# #message.getSubject()# to #destFolder.getName()#");
	        	arrayAppend(info,"Deleting source message #message.getMessageId()# #message.getSubject()#");
	        	msgCnt++;
	        }
	        sourceFolder.expunge();
			sourceFolder.close(true);
	        sourceFolder.open(Folder.READ_WRITE);
	        arrayAppend(info,"Moved messages.  Source (#sourceFolder.getName()#) has #arrayLen(sourceFolder.getMessages())#, dest (#destFolder.getName()#) has #arrayLen(destFolder.getMessages())#");
			sourceFolder.close(false);
			destFolder.close(false);
	        return info;
		</cfscript>
    </cffunction>

    <cffunction name="getMessageById" access="public" output="No" returntype="Array"
        hint="Get information about a specific folder.">
        <cfargument name="sourceFolder" required="Yes" type="object">
        <cfargument name="messageId" required="Yes" type="String">
		<cfscript>
            var MessageIDTerm = variables.fMessageIDTerm.init(messageId);
			var mSearch = sourceFolder.search(messageIdTerm);
			if (arrayLen(mSearch) == 1) {
				return mSearch;
			} else {
				return [];
			}
		</cfscript>
    </cffunction>

    <cffunction name="getMessageId" access="public" output="No" returntype="String"
        hint="Get message id.">
        <cfargument name="message" required="Yes" type="object">
		<cfscript>
			var headerValues = message.getHeader("Message-ID");
			if (arrayLen(headerValues) != 1) {
			     throw("Unexpected Message-ID header value count of #arrayLen(headerValues)# when expecting 1");
			}
			return headerValues[1];
		</cfscript>
    </cffunction>


    <cffunction name="syncFolder" access="public" output="No" returntype="Array"
        hint="syncs messages based on date recieved">
        <cfargument name="sourceFolder" required="Yes" type="object">
        <cfargument name="destFolder" required="Yes" type="object">
        <cfargument name="maxMessages" default="9999">
		<cfscript>
			var folder = variables.FolderClass;
			var info = [];
			var msgCnt = 0;
			sourceFolder.open(Folder.READ_ONLY);
			if (!destFolder.exists()) {
	            destFolder.create(Folder.HOLDS_MESSAGES);
	        }
	        destFolder.open(Folder.READ_WRITE);
	        arrayAppend(info,"Getting latest message in destination store");
            var SortTerm = createObject("java","com.sun.mail.imap.SortTerm");
	        var destMessages = destFolder.getSortedMessages(SortTerm.DATE);
	        var lastReceivedDate = "";
	        if (arrayLen(destMessages) != 0) {
		        for (message in destMessages) {
	        		arrayAppend(info,"existing message: #message.getSubject()#");
	        	}
	            var latest = destMessages[arrayLen(destMessages) - 1];
	            lastReceivedDate = latest.getReceivedDate();
	        }
	        if (lastReceivedDate == "") {
	            arrayAppend(info,"Getting #maxMessages# source messages");
	            messages = sourceFolder.getMessages(0,maxMessages);
	        } else {
	            arrayAppend(info,"Getting all source messages newer than " & lastReceivedDate);
	            var ReceivedDateTerm = createObject("java","javax.mail.search.ReceivedDateTerm");
	            var ComparisonTerm = createObject("java","javax.mail.search.ComparisonTerm");
	            rdt = ReceivedDateTerm.init(ComparisonTerm.GT, lastReceivedDate);
	            messages = sourceFolder.search(rdt);
	        }
	        arrayAppend(info,"Copying " & arrayLen(messages) & " messages");
	        for (message in messages) {
	            if (isDefined("lastReceivedDate") && lastReceivedDate != "") {
	                if (lastReceivedDate.getTime() >= message.getReceivedDate().getTime()) {
	                    continue;
	                }
	            }
	            if(msgCnt >= maxMessages) {
	            	break;
	            }
	        	msgCnt++;
	            destFolder.appendMessages([message]);
	        	arrayAppend(info,"Synced message #message.getMessageNumber()# #message.getSubject()#");
	        }
	        arrayAppend(info,"Synced messages.  Source had #arrayLen(messages)#, dest has #arrayLen(destMessages)#");
	        destFolder.close(false);
	        sourceFolder.close(false);
	        return info;
		</cfscript>
    </cffunction>

    <cffunction name="folderList" access="public" output="No" returnType="query"
        hint="Get a list of folders.">
        <cfargument name="folder" required="No" default="INBOX" type="string">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var columns = "foldername,foldertype,parent,msgcount,newmsgcount,unreadmsgcount,folderlevel,sortorder">
        <cfset var columnTypes = "varchar,integer,varchar,integer,integer,integer,integer,integer">
        <cfset var list = QueryNew(columns,columnTypes)>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, 0)>

        <cfset list = getFolderStructure(objFolder, "", list, 0)>
        <cfset variables.sortorder = 0>
        <cftry>
            <cfset objFolder.close(false)>
            <cfcatch type="any"><cfset addLog(cfcatch.message & cfcatch.detail)></cfcatch>
        </cftry>
        <cfreturn list>
    </cffunction>

    <cffunction name="copyMessages" access="public" output="No" returnType="boolean"
        hint="Copy messages from one folder to another.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="newFolder" required="Yes" type="string">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>
        <cfset var Messages = GetMessages(objFolder, arguments.messageNumber)>
        <cfset var destFolder = objStore.getFolder(arguments.newFolder)>

        <cfif NOT destFolder.exists()>
            <!--- destination folder does not exist --->
            <cfset objFolder.close(true)>
            <cfthrow message="Unable to copy messages" detail="The destination folder, #arguments.newFolder#, does not exist.">
        <cfelseif destFolder.getType() eq destFolder.HOLDS_FOLDERS>
            <!--- destination folder cannot hold messages --->
            <cfset objFolder.close(true)>
            <cfthrow message="Unable to copy messages" detail="The destination folder, #arguments.newfolder#, cannot contain messages.">
        <cfelse>
            <cfset objFolder.copyMessages(Messages, destFolder)>
            <cfset objFolder.close(true)>
            <cfreturn "Yes">
        </cfif>
    </cffunction>

    <cffunction name="folderDelete" access="public" output="No" returntype="boolean"
        hint="Delete a folder.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="recurse" required="No" type="boolean" default="false">
        <cfset var objFolder = getConnectedMailStore().getFolder(arguments.Folder)>
        <cfset objFolder.delete(arguments.recurse)>
        <cfreturn not objFolder.exists()>
    </cffunction>

    <cffunction name="folderCreate" access="public" output="No" returntype="boolean"
        hint="Create a folder.">
        <cfargument name="folder" required="Yes" type="string">
        <cfset getConnectedMailStore().getDefaultFolder().getFolder(arguments.Folder).create(true)>
        <cfreturn true>
    </cffunction>

    <cffunction name="folderRename" access="public" output="No" returntype="boolean"
        hint="Rename a folder.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="renameTo" required="Yes" type="string">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>

        <cfset objFolder.close(true)>
        <cfreturn objFolder.renameTo(objStore.getFolder(arguments.renameTo))>
    </cffunction>

    <cffunction name="getMessageCount" access="public" output="No" returnType="numeric"
        hint="Returns the number of messages in a folder.">
        <cfargument name="folder" required="No" default="Inbox" type="string">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, 0)>
				<cfset var messageCount = objFolder.getMessageCount()>
        <cfset objFolder.close(false)>
        <cfreturn messageCount />
    </cffunction>

    <cffunction name="listMessages" access="public" output="No" returnType="query"
        hint="Lists messages within a specified folder.">
        <cfargument name="folder" required="No" default="Inbox" type="string">
        <cfargument name="MessageNumber" default="" type="string">
        <cfargument name="startMessageNumber" default="1" type="numeric">
        <cfargument name="messageCount" default="0" type="numeric">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, 0)>
        <cfset var Messages = GetMessages(objFolder, arguments.MessageNumber,arguments.startMessageNumber,arguments.messageCount)>
        <cfset var Columns = "id,sent,recvdate,from,messagenumber,replyto,subject,recipients,cc,bcc,to,body,txtBody,seen,answered,deleted,draft,flagged,recent,user,attach,html,size">
        <cfset var ColumnTypes = "integer,date,date,varchar,integer,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,bit,bit,bit,bit,bit,bit,bit,varchar,bit,integer">
        <cfset var qry_Messages = QueryNew(Columns,columnTypes)>

        <cfset var objMessage = "">
		<cfset var recipients = "">
        <cfset var msgFrom = "">
        <cfset var msgTo = "">
        <cfset var msgCC = "">
        <cfset var msgBCC = "">
        <cfset var msgFlags = "">
        <cfset var fp = createObject("java","javax.mail.FetchProfile")>
		<cfset var x = 0>

        <cfset fp.init()>
        <cfset fp.add(variables.fProfileItem.ENVELOPE)>
        <cfset fp.add(variables.fProfileItem.FLAGS)>
        <Cfset objFolder.fetch(Messages,fp)>

        <cfloop from="1" to="#arrayLen(Messages)#" step="1" index="index">
            <cfset objMessage = Messages[index]>
            <cfset msgFrom = objMessage.getFrom()>
	        <cfset msgTo = "">
	        <cfset msgCC = "">
	        <cfset msgBCC = "">
	        <cfset msgFlags = "">
			<cfset recipients = ""/>
            <cfset msgTo = objMessage.getRecipients(variables.objRecipientType.TO)>
		        <cfset msgCC = objMessage.getRecipients(variables.objRecipientType.CC)>
		        <cfset msgBCC = objMessage.getRecipients(variables.objRecipientType.BCC)>
		        <cfif NOT isDefined("msgCC")>
						  <cfset msgCC = arrayNew(1) />
						</cfif>
		        <cfif NOT isDefined("msgBCC")>
						  <cfset msgBCC = arrayNew(1) />
						</cfif>
		        <cfif NOT isArray(msgCC)>
						  <cfset msgCC = listToArray(msgCC) />
						</cfif>
		        <cfif NOT isArray(msgBCC)>
						  <cfset msgBCC = listToArray(msgBCC) />
						</cfif>
            <cfif not isdefined("msgTo")>
                <cfset msgTo = ArrayNew(1)>
            </cfif>
		  <cfset recipients = listAppend(recipients,arrayToList(msgTo))>
		  <cfset recipients = listAppend(recipients,arrayToList(msgCC))>
		  <cfset recipients = listAppend(recipients,arrayToList(msgBCC))>

            <cfset msgFlags = objMessage.getFlags().getSystemFlags()>

            <cfset queryAddRow(qry_Messages)>
            <cfset querySetCell(qry_Messages,"id", index)>
            <cfset querySetCell(qry_Messages,"sent", objMessage.getSentDate())>
            <cfset querySetCell(qry_Messages,"recvdate", objMessage.getReceivedDate())>
            <cfset querySetCell(qry_Messages,"from", arrayToList(msgFrom))>
            <cfset querySetCell(qry_Messages,"messagenumber", objMessage.getMessageNumber())>
            <cfset querySetCell(qry_Messages,"subject", objMessage.getSubject())>
            <cfset querySetCell(qry_Messages,"recipients", recipients)>
            <cfset querySetCell(qry_Messages,"cc", arrayToList(msgCC))>
            <cfset querySetCell(qry_Messages,"bcc", arrayToList(msgBCC))>
            <cfset querySetCell(qry_Messages,"to", arrayToList(msgTo))>
            <cfset querySetCell(qry_Messages,"size", objMessage.getSize())>
            <cfset querySetCell(qry_Messages,"seen", false)>
            <cfset querySetCell(qry_Messages,"answered", false)>
            <cfset querySetCell(qry_Messages,"deleted", false)>
            <cfset querySetCell(qry_Messages,"draft", false)>
            <cfset querySetCell(qry_Messages,"flagged", false)>
            <cfset querySetCell(qry_Messages,"user", false)>
            <cfset querySetCell(qry_Messages,"recent", false)>
            <cfloop from="1" to="#arrayLen(msgFlags)#" step="1" index="i">
                <cfif msgFlags[i].equals(variables.objFlag.SEEN)>
                    <cfset querySetCell(qry_Messages,"seen", true)>
                <cfelseif msgFlags[i].equals(variables.objFlag.ANSWERED)>
                    <cfset querySetCell(qry_Messages,"answered", true)>
                <cfelseif msgFlags[i].equals(variables.objFlag.DELETED)>
                    <cfset querySetCell(qry_Messages,"deleted", true)>
                <cfelseif msgFlags[i].equals(variables.objFlag.DRAFT)>
                    <cfset querySetCell(qry_Messages,"draft", true)>
                <cfelseif msgFlags[i].equals(variables.objFlag.FLAGGED)>
                    <cfset querySetCell(qry_Messages,"flagged", true)>
                <cfelseif msgFlags[i].equals(variables.objFlag.USER)>
                    <cfset querySetCell(qry_Messages,"user", true)>
                <cfelseif msgFlags[i].equals(variables.objFlag.RECENT)>
                    <cfset querySetCell(qry_Messages,"recent", true)>
                </cfif>
            </cfloop>
        </cfloop>
        <cfset objFolder.close(false)>
        <cfquery dbtype="query" name="qry_Messages">
            select * from qry_Messages
            order by id desc
        </cfquery>
        <cfreturn qry_Messages>
    </cffunction>

    <cffunction name="getMessage" access="public" output="Yes"
        hint="Get a specific message from a folder.">
        <cfargument name="folder" required="No" default="Inbox" type="string">
        <cfargument name="MessageNumber" required="No" default="1" type="numeric">
        <cfargument name="text" required="No" default="false" type="boolean">

        <cfset var objStore = getConnectedMailStore()> <!--- javax.mail.Store --->
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, 0)> <!--- javax.mail.folder --->
        <cfset var Messages = GetMessages(objFolder, arguments.MessageNumber)><!--- array of com.sun.mail.imap.IMAPMessage (javax.mail.Message) --->
        <cfset var objMessage = "">

        <cfset var Columns = "id,sent,recvdate,from,messagenumber,replyto,subject,recipients,cc,bcc,to,body,txtBody,seen,answered,deleted,draft,flagged,recent,user,attach,html,size">
        <cfset var ColumnTypes = "integer,date,date,varchar,integer,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,bit,bit,bit,bit,bit,bit,bit,varchar,bit,integer">
        <cfset var qry_Messages = QueryNew(Columns,columnTypes)>
        <cfset var recipients = "">
        <cfset var msgFrom = "">
        <cfset var msgTo = "">
        <cfset var msgCC = "">
        <cfset var msgBCC = "">
        <cfset var msgReplyTo = "">
        <cfset var msgFlags = "">
				<cfset var msgFlag = "">
        <cfset var msgBody = "">
        <cfset var msgTxtBody = "">
        <cfset var msgAttachments = "">
        <cfset var msgIsHTML = false>

        <cfset var parts = arrayNew(2)>
        <cfset var i = 0>

        <cfif arrayLen(Messages) is 0>
            <Cfthrow message="Message Not Found" detail="The specified message number was not found in the specified folder.">
        </cfif>

        <cfset objMessage = Messages[1]><!--- com.sun.mail.imap.IMAPMessage (javax.mail.Message) --->

        <!--- envelope details and flags --->
        <cfset msgFrom = objMessage.getFrom()>
        <cfset msgTo = objMessage.getRecipients(variables.objRecipientType.TO)>
        <cfset msgCC = objMessage.getRecipients(variables.objRecipientType.CC)>
        <cfset msgReplyTo = objMessage.getReplyTo()>
        <cfset msgFlags = objMessage.getFlags().getSystemFlags()>
        <cfset msgBCC = objMessage.getRecipients(variables.objRecipientType.BCC)>
        <cfif NOT isDefined("msgCC")>
				  <cfset msgCC = arrayNew(1) />
				</cfif>
        <cfif NOT isDefined("msgBCC")>
				  <cfset msgBCC = arrayNew(1) />
				</cfif>
        <cfif NOT isArray(msgCC)>
				  <cfset msgCC = listToArray(msgCC) />
				</cfif>
        <cfif NOT isArray(msgBCC)>
				  <cfset msgBCC = listToArray(msgBCC) />
				</cfif>
        <cfif not isdefined("msgTo")>
             <cfset msgTo = ArrayNew(1)>
        </cfif>
			  <cfset recipients = listAppend(recipients,arrayToList(msgTo))>
			  <cfset recipients = listAppend(recipients,arrayToList(msgCC))>
			  <cfset recipients = listAppend(recipients,arrayToList(msgBCC))>

        <cfif (objMessage.isMimeType("text/*") AND NOT objMessage.isMimeType("text/rfc822-headers")) OR isSimpleValue(objMessage.getContent())>
            <!--- it is NOT a multipart message --->
            <cfset encoding = objMessage.getEncoding()>
            <!--- look for quoted-printable --->
            <cfset content = objMessage.getContent()>
            <cfset parts[1][1] = content>
            <cfif refindnocase("<html[0-9a-zA-Z= ""/:.]*>", content)>
                <cfset parts[1][2] = 2>
            <cfelse>
                <cfset parts[1][2] = 1>
            </cfif>
        <cfelse>
            <cfset getPartsResult = getParts(objMessage)>
            <cfset parts = getPartsResult.parts>
            <cfset msgAttachments = getPartsResult.attachments>
        </cfif>

        <!--- compile the parts --->
        <!--- are there any HTML parts? --->
        <cfloop from="1" to="#arraylen(parts)#" index="i">
            <cfif parts[i][2] is 2>
                <cfset msgIsHtml = true>
            </cfif>
        </cfloop>
        <!--- compile the message body --->
        <cfloop from="1" to="#arraylen(parts)#" index="i">
            <cfif parts[i][2] is 2>
                <!--- only add HTML parts to the body --->
                <cfset msgBody = msgBody & parts[i][1]>
                <cfif arraylen(parts) gt i>
                    <cfset msgBody = msgBody & "<hr>">
                </cfif>
            <cfelse>
                <!--- only add text parts to txtBody --->
                <cfset msgTxtBody = msgTxtBody & htmlEditFormat(parts[i][1])>
            </cfif>
        </cfloop>
        <!--- add message to the return query --->
        <cfset queryAddRow(qry_Messages)>
        <cfset querySetCell(qry_Messages,"id", 1)>
        <cfset querySetCell(qry_Messages,"size", objMessage.getSize())>
        <cfset querySetCell(qry_Messages,"replyto", msgReplyTo)>
        <cfset querySetCell(qry_Messages,"sent", objMessage.getSentDate())>
        <cfset querySetCell(qry_Messages,"recvdate", objMessage.getReceivedDate())>
        <cfset querySetCell(qry_Messages,"from", arrayToList(msgFrom))>
        <cfset querySetCell(qry_Messages,"messagenumber", objMessage.getMessageNumber())>
        <cfset querySetCell(qry_Messages,"subject", objMessage.getSubject())>
        <cfset querySetCell(qry_Messages,"to", arrayToList(msgTo))>
        <cfset querySetCell(qry_Messages,"recipients", recipients)>
        <cfset querySetCell(qry_Messages,"cc", arrayToList(msgCC))>
        <cfset querySetCell(qry_Messages,"bcc", arrayToList(msgBCC))>
        <cfset querySetCell(qry_Messages,"body", msgBody)>
        <cfset querySetCell(qry_Messages,"txtBody", msgTxtBody)>
        <cfset querySetCell(qry_Messages,"html", msgIsHtml)>
        <cfset querySetCell(qry_Messages,"attach", msgAttachments)>
        <cfset querySetCell(qry_Messages,"seen", false)>
        <cfset querySetCell(qry_Messages,"answered", false)>
        <cfset querySetCell(qry_Messages,"deleted", false)>
        <cfset querySetCell(qry_Messages,"draft", false)>
        <cfset querySetCell(qry_Messages,"flagged", false)>
        <cfset querySetCell(qry_Messages,"user", false)>
        <cfset querySetCell(qry_Messages,"recent", false)>
        <cfloop from="1" to="#arrayLen(msgFlags)#" step="1" index="i">
						<cfset msgFlag = toString(msgFlags[i])>
            <cfif msgFlag eq toString(variables.objFlag.SEEN)>
                <cfset querySetCell(qry_Messages,"seen", true)>
            <cfelseif msgFlag eq toString(variables.objFlag.ANSWERED)>
                <cfset querySetCell(qry_Messages,"answered", true)>
            <cfelseif msgFlag eq toString(variables.objFlag.DELETED)>
                <cfset querySetCell(qry_Messages,"deleted", true)>
            <cfelseif msgFlag eq toString(variables.objFlag.DRAFT)>
                <cfset querySetCell(qry_Messages,"draft", true)>
            <cfelseif msgFlag eq toString(variables.objFlag.FLAGGED)>
                <cfset querySetCell(qry_Messages,"flagged", true)>
            <cfelseif msgFlag eq toString(variables.objFlag.USER)>
                <cfset querySetCell(qry_Messages,"user", true)>
            <cfelseif msgFlag eq toString(variables.objFlag.RECENT)>
                <cfset querySetCell(qry_Messages,"recent", true)>
            </cfif>
        </cfloop>
        <cfset objFolder.close(false)>
        <cfreturn qry_Messages>
    </cffunction>

    <cffunction name="expunge" access="public" output="No" returntype="boolean"
        hint="Expunge deleted messages from a folder.">
        <cfargument name="folder" required="Yes" type="string">
        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = "">

        <cftry>
            <cfset objFolder = OpenFolder(objStore, arguments.folder, true)>
            <cfset objFolder.expunge()>
            <cfset objFolder.close(false)>
            <cfcatch type="any">
                <!--- folder cannot be expunged --->
            </cfcatch>
        </cftry>
        <cfreturn true>
    </cffunction>

    <cffunction name="delete" access="public" output="No" returntype="boolean"
        hint="Sets the message's DELETED flag.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="value" required="Yes" type="boolean">

        <cfset var msgnum = 0>
        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>

        <cfloop list="#listSort(messagenumber,"numeric","desc")#" index="msgnum">
            <cfif isNumeric(msgnum) and msgnum gt 0>
                <cfset setFlag(objFolder, msgnum, "DELETED", arguments.value)>
            </cfif>
        </cfloop>
        <cfset objFolder.close(false)>
        <cfreturn true>
    </cffunction>

    <cffunction name="setAnswered" access="public" output="No" returntype="boolean"
        hint="Sets the message's ANSWERED flag.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="value" required="Yes" type="boolean">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>

        <cfset setFlag(objFolder, arguments.messageNumber, "ANSWERED", arguments.value)>
        <cfset objFolder.close(false)>
        <cfreturn true>
    </cffunction>

    <cffunction name="setSeen" access="public" output="No" returntype="boolean"
        hint="Sets the message's SEEN flag.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="value" required="Yes" type="boolean">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>

        <cfset setFlag(objFolder, arguments.messageNumber, "SEEN", arguments.value)>
        <cfset objFolder.close(false)>
        <cfreturn true>
    </cffunction>

    <cffunction name="setDraft" access="public" output="No" returntype="boolean"
        hint="Sets the message's DRAFT flag.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="value" required="Yes" type="boolean">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>

        <cfset setFlag(objFolder, arguments.messageNumber, "DRAFT", arguments.value)>
        <cfset objFolder.close(false)>
        <cfreturn true>
    </cffunction>

    <cffunction name="setFlagged" access="public" output="No" returntype="boolean"
        hint="Sets the message's FLAGGED flag.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="value" required="Yes" type="boolean">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>

        <cfset setFlag(objFolder, arguments.messageNumber, "FLAGGED", arguments.value)>
        <cfset objFolder.close(false)>
        <cfreturn true>
    </cffunction>

    <cffunction name="setRecent" access="public" output="No" returntype="boolean"
        hint="Sets the message's RECENT flag.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="value" required="Yes" type="boolean">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>

        <cfset setFlag(objFolder, arguments.messageNumber, "RECENT", arguments.value)>
        <cfset objFolder.close(false)>
        <cfreturn true>
    </cffunction>

    <cffunction name="setUser" access="public" output="No" returntype="boolean"
        hint="Sets the message's USER flag.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="value" required="Yes" type="boolean">

        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, true)>

        <cfset setFlag(objFolder, arguments.messageNumber, "USER", arguments.value)>
        <cfset objFolder.close(false)>
        <cfreturn true>
    </cffunction>


    <cffunction name="send" access="public" output="No" returntype="boolean">
    	<cfargument name="to" required="Yes" type="string">
    	<cfargument name="cc" type="string" default="" >
    	<cfargument name="bcc" type="string" default="" >
    	<cfargument name="subject" type="string" default="">
    	<cfargument name="body" required="Yes" type="string">
    	<cfargument name="attachments" required="No" type="string" default="">

    	<cfset var msg = CreateObject("Java", "javax.mail.internet.MimeMessage") />
    	<cfset var mmp = CreateObject("Java", "javax.mail.internet.MimeMultipart") />
    	<cfset var mbp = CreateObject("Java", "javax.mail.internet.MimeBodyPart") />
    	<cfset var dhl = CreateObject("Java", "javax.activation.DataHandler") />
    	<cfset var fds = CreateObject("Java", "javax.activation.FileDataSource") />
    	<cfset var add = CreateObject("Java", "javax.mail.internet.InternetAddress") />
    	<cfset var auther = CreateObject("Java", "javax.mail.PasswordAuthentication") />


    	<cfset var Timeout = variables._instance.protocolTimeout * 1000 />
    	<cfset var index = "" />
    	<cfset var objFolder = "" />
    	<cfset var Messages = "" />
		<cfset var sesh = variables._instance.session />
    	<cfset var transport = sesh.getTransport("smtp") />
    	<cfset msg.init(sesh) />
    	<cfset msg.setFrom(add.init(variables._instance.username)) />
    	<cfset msg.addRecipients(variables.objRecipientType.TO, add.parse(replace(arguments.to, ";", ", ", "ALL"), false)) />
    	<cfset msg.addRecipients(variables.objRecipientType.CC, add.parse(replace(arguments.cc, ";", ", ", "ALL"), false)) />
    	<cfset msg.addRecipients(variables.objRecipientType.BCC, add.parse(replace(arguments.bcc, ";", ", ", "ALL"), false)) />
    	<cfset msg.setSubject(arguments.subject) />
    	<cfset msg.setText(arguments.body) />
    	<cfset msg.setHeader("X-Mailer", "Koolwired IMAP Web Client (http://www.koolwired.com)") />
    	<cfset msg.setSentDate(now()) />
    	<cfif len(arguments.attachments)>
    		<cfset mbp.init() />
    		<cfset mbp.setText(arguments.body) />
    		<cfset mmp.addBodyPart(mbp) />
    		<cfloop list="#arguments.attachments#" index="index">
    			<cfset fds.init(getTempDirectory() & index) />
    			<cfset mbp.init() />
    			<cfset mbp.setDataHandler(dhl.init(fds)) />
    			<cfset mbp.setFileName(fds.getName()) />
    			<cfset mmp.addBodyPart(mbp) />
    		</cfloop>
    		<cfset msg.setContent(mmp) />
    	</cfif>
    	<cfset msg.saveChanges() />
<!---
		<cfset transport.connect(variables._instance.mailServer,variables._instance.mailServerPort,variables._instance.username,variables._instance.password) />
 --->
		<cfset transport.connect(variables._instance.mailServer, variables._instance.mailServerPort, variables._instance.username,variables._instance.password) />
    	<!---
    	<cfset addLog(transport.isConnected()) />
    		<cfif transport.getRequireStartTLS() AND NOT variables._instance.useTLS>
    		<cfthrow type="cfjavamail.error.tls.required" message="TLS is required.  Set useTLS attribute to true.">
    		</cfif>
          	<cfset request.debug(toString(sesh.getDebugOut()))/>
   		--->
    	<cfset transport.sendMessage(msg,msg.getAllRecipients()) />
    	<cfset transport.close() />
<!---
this needs to be done at a higher level!
    	<cfset objStore = getConnectedMailStore() />
    	<cfset objFolder = OpenFolder(objStore, "Inbox.Sent", true, true) />
    	<cfset Messages = ArrayNew(1) />
    	<cfset Messages[1] = msg />
    	<cfset objFolder.appendMessages(Messages) />
 --->
    	<cfreturn true />
    </cffunction>


    <cffunction name="download" access="public" output="Yes"
        hint="Take a specific attachment from a message and return the details - along with the binary data.">
        <cfargument name="folder" required="Yes" type="string">
        <cfargument name="MessageNumber" required="Yes" type="numeric">
        <cfargument name="Attach" required="Yes" type="string">
        <cfargument name="includeData" required="no" type="boolean" default="true">
        <!---
            I think it's worth mentioning that this may not be very efficient for
            really big files because you end up writing the files twice.
        --->
        <cfset var objStore = getConnectedMailStore()>
        <cfset var objFolder = OpenFolder(objStore, arguments.folder, 0)>
        <cfset var Messages = GetMessages(objFolder, arguments.MessageNumber)>
        <cfset var attachment = StructNew()>
        <cfset var byteArray = repeatString(" ", 1000).getBytes()>
        <cfset var part = CreateObject("Java", "javax.mail.Part")>
        <cfset var i = 0>
        <cfset var fo = "">
        <cfset var fso = "">
        <cfset var in = "">
        <cfset var tempFile = "">
        <cfset var j = "">
        <cfset var fileContents = "">
        <cfset var messageParts = Messages[1].getContent()>
        <cfset var listfiles = "">

        <cfloop from="0" to="#messageParts.getCount() - 1#" index="i">
            <cfset part = messageParts.getBodyPart(javacast("int", i))>
            <cfif not(findnocase("text/text", part.getContentType())) and part.getFileName() is arguments.Attach>
                <cfset StructInsert(attachment, "name", part.getFileName())>
                <cfset StructInsert(attachment, "type", part.getContentType())>
                <cfset fo = createObject("Java", "java.io.File")>
                <cfset fso = createObject("Java", "java.io.FileOutputStream")>
                <cfset in = part.getInputStream()>
                <cfset randomize(second(now()) + minute(now()) * 60)>
                <cfset tempFile = getTempDirectory() & variables._instance.SessionID & "-" & randrange(1,100) & "-" & part.getFileName()>
                <cfset fo.init(tempFile)>
                <cfset fso.init(fo)>
                <cfset j = in.read(byteArray)>
                <cfloop condition="not(j is -1)">
                    <cfset fso.write(byteArray, 0, j)>
                    <cfset j = in.read(byteArray)>
                </cfloop>
                <cfset fso.close()>
                <cfif includeData>
                    <cffile action="READBINARY" file="#tempFile#" variable="fileContents">
                    <cffile action="DELETE" file="#tempFile#">
                    <cfset StructInsert(attachment, "data", fileContents)>
                    <cfset StructInsert(attachment, "length", ArrayLen(fileContents))>
                <cfelse>
                    <cfdirectory action="LIST" directory="#getDirectoryFromPath(tempFile)#" name="listFiles" filter="#getFileFromPath(tempFile)#">
                    <cfloop query="listfiles">
                        <cfif listFiles.name eq getFileFromPath(tempfile)>
                            <cfset StructInsert(attachment, "data", '')>
                            <cfset StructInsert(attachment, "length", size)>
                        </cfif>
                    </cfloop>
                </cfif>
            </cfif>
        </cfloop>
        <cfset objFolder.close(false)>
        <cfreturn attachment>
    </cffunction>

	<cffunction name="getLog" access="public" output="false">
		<cfreturn _log />
	</cffunction>

<!--- ################################################## --->
<!--- ################################################## --->
<!---                                                    --->
<!---                   PRIVATE METHODS                  --->
<!---                                                    --->
<!--- ################################################## --->
<!--- ################################################## --->

	<cffunction name="addLog" access="private" output="false">
		<cfargument name="message" required="true" />
		<cfargument name="type" default="INFO" />
		<cfset arrayAppend(_log,"#ucase(type)#: #serializeJSON(message)#")>
	</cffunction>

    <cffunction name="getConnectedMailStore" access="private" output="No"
        hint="Returns the existing mail store object that is in memory as long as the connection properties (username, server, port) are the same, or creates a new connected mail store object.">
        <cfset var connectionProperties = variables._instance.username & variables._instance.mailServer & variables._instance.mailServerPort>
        <cfif
            isDefined("variables._instance.connectionProperties")
            and variables._instance.connectionProperties eq connectionProperties
            and isDefined("variables._instance.connection")
            and not isSimpleValue(variables._instance.connection)
            and variables._instance.connection.isConnected()>
            <!---
                We have connection properties in variables._instance.
                They are the same as the connection properties we passed in.
                variables._instance.connection already exists
                and it's a mail store object
                and it's connected

                So, return the existing connection from the session scope.
            --->
			<cfset addLog("session existed:" & connectionProperties)>
            <cfreturn variables._instance.connection>
        <cfelse>
			<cfset addLog("new session:" & connectionProperties)>
            <!--- get a new connected mail store and put it in the session scope --->
            <cfset variables._instance.connection = GetStore()>
            <!--- put the connection properties into the session scope --->
            <cfset variables._instance.connectionProperties = connectionProperties>
            <!--- return the new mail store --->
            <cfreturn variables._instance.connection>
        </cfif>
    </cffunction>

    <cffunction name="GetStore" access="private" output="No"
    	hint="Gets a connected mail store object (ie, connect to server, authenticate, etc)">
    	<cfset var clsSession = createObject("Java", "javax.mail.Session") />
    	<cfset var objProperties = createObject("Java", "java.util.Properties") />
    	<cfset var objStore = createObject("Java", "javax.mail.Store") />
    	<cfset var protocol = lcase(variables._instance.protocol) />
    	<cfset var useTLS = variables._instance.useTLS />
    	<cfset var useSSL = variables._instance.useTLS />
    	<cfset var allowFallback = variables._instance.allowFallback />
		<cfset var connectionhash = variables._instance.connectionhash />
		<cfset var urlName = "" />
    	<cfif sessionEnabled() AND NOT structKeyExists(session,"_cfjavamail_#connectionhash#")>
    		<!--- we're out of session! --->
    		<cfthrow message="Session Time Out" detail="Your session has timed out and you are no longer connected.  Please log in again.">
    	</cfif>
    	<!--- set up the type of connection --->
    	<cfset objProperties.init() />
    	<cfif useTLS>
    		<cfset createObject('java',"java.lang.System").setProperty("javax.net.debug", "ssl,handshake") />
    		<cfset objProperties.put("mail.smtp.starttls.enable", "true") />
    		<!--- <cfset objProperties.put("mail.smtp.ssl.protocols", "SSLv3 TLSv1") /> --->
    	</cfif>
    	<!--- handle ssl connections --->
    	<cfif protocol eq "imaps">
    		<cfset objProperties.put("mail.imap.socketFactory.class", "javax.net.ssl.SSLSocketFactory") />
    		<cfset objProperties.put("mail.imap.socketFactory.fallback", false) />
    		<cfset objProperties.put("mail.store.protocol", "imaps") />
    		<cfif variables._instance.mailServerPort neq 0>
    			<cfset objProperties.put("mail.imap.socketFactory.port", variables._instance.mailServerPort) />
    			<cfset objProperties.put("mail.imap.port", variables._instance.mailServerPort) />
    		</cfif>
    		<cfset objProperties.put("mail.imap.connectiontimeout", variables._instance.protocolTimeout) />
    		<!--- milliseconds --->
    		<cfset objProperties.put("mail.imap.timeout", variables._instance.protocolTimeout) />
    	<cfelseif protocol eq "imap">
    		<cfset objProperties.put("mail.store.protocol", "imap") />
    		<cfif variables._instance.mailServerPort neq 0>
    			<cfset objProperties.put("mail.imap.socketFactory.port", variables._instance.mailServerPort) />
    			<cfset objProperties.put("mail.imap.port", variables._instance.mailServerPort) />
    		</cfif>
    		<cfset objProperties.put("mail.imap.connectiontimeout", variables._instance.protocolTimeout) />
    		<!--- milliseconds --->
    		<cfset objProperties.put("mail.imap.timeout", variables._instance.protocolTimeout) />
    		<!--- milliseconds --->
    	<cfelseif protocol eq "mstor">
    		<cfscript>
    			objProperties.setProperty("mail.store.protocol", "mstor");
    			objProperties.setProperty("mstor.mbox.metadataStrategy", "yaml");
    			//objProperties.setProperty("mstor.mbox.metadataStrategy", "xml");
    		</cfscript>
    	<cfelseif protocol eq "pop">
    		<cfscript>
    			if(variables._instance.mailServerPort neq 0) {
    			objProperties.setProperty("mail.pop.socketFactory.port", variables._instance.mailServerPort);
    			objProperties.setProperty("mail.pop.port",  variables._instance.mailServerPort);
    			}
    			objProperties.setProperty("mail.store.protocol", "pop");
    			objProperties.setProperty("mail.pop.socketFactory.fallback", "false");
    			objProperties.setProperty("mail.pop.connectiontimeout",  variables._instance.protocolTimeout);
    			objProperties.setProperty("mail.pop.timeout",  variables._instance.protocolTimeout);
    		</cfscript>
    	<cfelseif protocol eq "pop3">
    		<cfscript>
    			if(variables._instance.mailServerPort neq 0) {
    				objProperties.setProperty("mail.pop3.socketFactory.port", variables._instance.mailServerPort);
    				objProperties.setProperty("mail.pop3.port",  variables._instance.mailServerPort);
    			}
    			objProperties.setProperty("mail.store.protocol", "pop3");
    			objProperties.setProperty("mail.pop3.socketFactory.class", "javax.net.ssl.SSLSocketFactory");
    			objProperties.setProperty("mail.pop3.socketFactory.fallback", "false");
    			objProperties.setProperty("mail.pop3.connectiontimeout",  variables._instance.protocolTimeout);
    			objProperties.setProperty("mail.pop3.timeout",  variables._instance.protocolTimeout);
    		</cfscript>

    	<cfelseif protocol eq "smtp">
    		<cfset objProperties.put("mail.transport.protocol", "smtp") />
    		<cfset objProperties.put("mail.smtp.host", "#variables._instance.mailserver#") />
<!---
    		<cfset objProperties.put("mail.host", "#variables._instance.mailserver#") />
    		<cfset objProperties.put("mail.user", "#variables._instance.username#") />
    		<cfset objProperties.put("mail.password", "#variables._instance.password#") />
 --->
    		<cfif variables._instance.mailServerPort neq 0>
					<cfset objProperties.put("mail.smtp.port", "#variables._instance.mailserverPort#") />
					<cfset objProperties.put("mail.smtp.socketFactory.port", "#variables._instance.mailserverPort#") />
				</cfif>
				<cfif variables._instance.username neq "">
					<cfset objProperties.put("mail.smtp.auth", "true") />
				</cfif>
				<cfset objProperties.put("mail.smtp.socketFactory.fallback", "#allowFallback#") />
    		<cfif variables._instance.useTLS>
    			<cfscript>
    				objProperties.put("mail.smtp.starttls.enable", "true");
    			</cfscript>
    			<!--- <cfset objProperties.put("mail.smtp.quitwait",false) /> --->
    		</cfif>
    		<cfif variables._instance.useSSL>
    			<cfscript>
    				objProperties.put("mail.smtp.socketFactory.class","javax.net.ssl.SSLSocketFactory");
    			</cfscript>
    			<!--- <cfset objProperties.put("mail.smtp.quitwait",false) /> --->
    		</cfif>
    	<cfelse>
    		<cfthrow type="cfjavamail.unknown.protocol" message="Unrecognized protocol: #protocol#" detail="Unrecognized protocol: #protocol#" />
    	</cfif>
    	<!--- start the session --->
    	<cfset objSession = clsSession.getInstance(objProperties) />
    	<cfset variables._instance.session = objSession />
    	<!--- start the mailstore --->
    	<cfif protocol eq "mstor">
			<cfset urlName = createObject("java","javax.mail.URLName").init(variables._instance.mailServer) />
    		<cfset objStore = createObject("java","net.fortuna.mstor.MStorStore").init(objSession,urlName) />
    		<!--- connect and authenticate --->
    		<cftry>
    			<cfset objStore.connect(variables._instance.mailServer, variables._instance.username, variables._instance.password) />
    			<cfcatch>
    				<cfthrow type="imap.connection.error" message="Unable to connect" detail="unable to connect to specified host.  Please verify the host name. (#cfcatch.message# #cfcatch.detail#)">
    			</cfcatch>
    		</cftry>
    	<cfelseif protocol neq "smtp">
    		<cfset objStore = objSession.getStore() />
    		<!--- connect and authenticate --->
    			<cfset objStore.connect(variables._instance.mailServer, variables._instance.mailServerPort, variables._instance.username, variables._instance.password) />
    		<cftry>
    			<cfcatch>
    				<cfthrow type="imap.connection.error" message="Unable to connect" detail="unable to connect to specified host.  Please verify the host name. (#cfcatch.message# #cfcatch.detail#)">
    			</cfcatch>
    		</cftry>
    	<cfelse>
    		<cfset objStore = "" />
    	</cfif>
    	<cfreturn objStore />
    </cffunction>

 <cffunction name="OpenFolder" access="private" output="No" hint="Opens a fol
der within a mail store and returns the folder object.">
        <cfargument name="objStore" required="Yes" type="any">
        <cfargument name="Folder" required="Yes" type="string">
        <cfargument name="ReadWrite" required="No" type="boolean" default="false">
        <cfargument name="Create" required="No" type="boolean" default="false">

        <cfset var objFolder = arguments.objStore.getDefaultFolder().getFolder(arguments.Folder)>

        <cftry>
            <cfif NOT objFolder.exists() AND arguments.create>
                <cfset objFolder.create(true)>
            </cfif>
            <cfif ReadWrite>
                <cfset objFolder.open(objFolder.READ_WRITE)>
            <cfelse>
                <cfset objFolder.open(objFolder.READ_ONLY)>
            </cfif>
            <cfcatch type="any">
                <!--- folder cannot be opened --->
            </cfcatch>
        </cftry>
        <cfreturn objFolder>
    </cffunction>

    <cffunction name="GetMessages" access="private" output="No" returnType="array"
         hint="Retrieves messages from a folder, given a folder object and an optional comma separated list of message numbers.">
         <cfargument name="objFolder" required="Yes" type="any">
         <cfargument name="messageNumber" required="no" default="">
         <cfargument name="startMessageNumber" default="1" type="numeric">
         <cfargument name="messageCount" default="0" type="numeric">
         <cfset var Messages = ArrayNew(1)>
         <cftry>
              <cfif ListLen(arguments.messageNumber) gt 0>
                   <cfset Messages = arguments.objFolder.getMessages(ListToArray(arguments.messageNumber))>
              <cfelseif val(arguments.messageCount) neq 0>
                   <cfset Messages = arguments.objFolder.getMessages(javacast("int",arguments.startMessageNumber),javacast("int",arguments.messageCount))>
                   <cftry>
                        <cfcatch>
                             <!--- <cfset Messages = arguments.objFolder.getMessages(javacast("int",arguments.startMessageNumber),(arguments.objFolder.getMessageCount()-arguments.startMessageNumber))> --->
                             <cfset Messages = arguments.objFolder.getMessages()>
                        </cfcatch>
                   </cftry>
              <cfelse>
                   <cfset Messages = arguments.objFolder.getMessages()>
              </cfif>
              <cfcatch type="any">
                   <!--- folder probably isn't allowed to cotnain messages --->
              </cfcatch>
         </cftry>
         <!--- array of javax.mail.Message --->
         <cfreturn Messages>
    </cffunction>


    <cffunction name="GetMessagesByRange" access="private" output="No" returnType="array"
        hint="Retrieves range of messages from a folder, given a folder object and range.">
        <cfargument name="objFolder" required="Yes" type="any">
        <cfargument name="messageNumber" required="no" default="">

        <cfset var Messages = ArrayNew(1)>
        <cftry>
           <cfset Messages = arguments.objFolder.getMessages(javacast("int",arguments.startMessageNumber),javacast("int",arguments.messageCount))>
            <cfcatch type="any">
                <!--- folder probably isn't allowed to cotnain messages --->
            </cfcatch>
        </cftry>
        <!--- array of javax.mail.Message --->
        <cfreturn Messages>
    </cffunction>

    <cffunction name="getFolderStructure" access="private" output="Yes" returntype="query"
        hint="Recursive method for returning the structure of a folder (including all subfolders).">
        <cfargument name="objFolder" required="Yes" type="any">
        <cfargument name="folder" required="yes" type="string">
        <cfargument name="list" required="yes" type="query">
        <cfargument name="level" required="Yes" type="numeric">
        <cfargument name="stack" required="no" type="array" default="#ArrayNew(1)#">

        <cfset var Folders = "">
        <cfset var i = "">
        <cfset var path = "">
        <cfset var msgcount = 0>
        <cfset var newmsgcount = 0>
        <cfset var unreadmsgcount = 0>

        <cfset variables.sortOrder = variables.sortOrder + 1>
        <cfif len(arguments.folder)>
            <!--- use the folder name to get the folder object --->
            <cfset arguments.objFolder = arguments.objFolder.getFolder(arguments.folder)>
        </cfif>
				<cfif NOT arguments.objFolder.exists()>
					<cfthrow type="cfjavamail.folder.not.there" message="the folder: #arguments.objFolder.getName()# does not exist!" detail="the folder: #arguments.objFolder.getName()# does not exist!">
				</cfif>
				<cfif lcase(left(variables._instance.protocol,3)) eq "pop">
					<!--- POP apparently only has one folder, the INBOX --->
					<cfset queryAddRow(arguments.list)>
					<cfset querySetCell(arguments.list, "foldername", arguments.objFolder.getName())>
					<cfset querySetCell(arguments.list, "foldertype", arguments.objFolder.getType())>
					<cfset querySetCell(arguments.list, "parent", path & arguments.objFolder.getParent().getName())>
					<cfset querySetCell(arguments.list, "folderlevel", arguments.level)>
					<cfset querySetCell(arguments.list, "sortorder", variables.sortorder)>
					<cfreturn arguments.list />
				<cfelse>
	        <cfset Folders = arguments.objFolder.list() />
				</cfif>
        <cfloop from="1" to="#ArrayLen(Folders)#" step="1" index="i">
            <cftry>
                <cfset path = arraytolist(arguments.stack, ".")>
                <cfif len(path)>
                    <cfset path = path & ".">
                </cfif>
                <cfset queryAddRow(arguments.list)>
                <cfset querySetCell(arguments.list, "foldername", Folders[i].getName())>
                <cfset querySetCell(arguments.list, "foldertype", Folders[i].getType())>
                <cfset querySetCell(arguments.list, "parent", path & Folders[i].getParent().getName())>
                <cfset querySetCell(arguments.list, "folderlevel", arguments.level)>
                <cfset querySetCell(arguments.list, "sortorder", variables.sortorder)>
                <cfif Folders[i].getType() eq Folders[i].HOLDS_FOLDERS>
                    <!--- folder doesn't contain messages --->
                    <cfset querySetCell(arguments.list, "msgcount", 0)>
                    <cfset querySetCell(arguments.list, "newmsgcount", 0)>
                    <cfset querySetCell(arguments.list, "unreadmsgcount", 0)>
                <cfelse>
                    <cftry>
                        <cfset msgcount = Folders[i].getMessageCount()>
                        <cfcatch type="any"><cfset msgcount = 0></cfcatch>
                    </cftry>
                    <cfset querySetCell(arguments.list, "msgcount", msgcount)>
                    <cfif msgcount lte 0>
                        <!--- if there are no messages, there won't be any
                            new or unread messages --->
                        <cfset querySetCell(arguments.list, "newmsgcount", 0)>
                        <cfset querySetCell(arguments.list, "unreadmsgcount", 0)>
                    <cfelse>
                        <cftry>
                            <cfset newmsgcount = Folders[i].getNewMessageCount()>
                            <cfcatch type="any"><cfset newmsgcount = 0></cfcatch>
                        </cftry>
                        <cfset querySetCell(arguments.list, "msgcount", newmsgcount)>
                        <cftry>
                            <cfset unreadmsgcount = Folders[i].getUnreadMessageCount()>
                            <cfcatch type="any"><cfset unreadmsgcount = 0></cfcatch>
                        </cftry>
                        <cfset querySetCell(arguments.list, "msgcount", unreadmsgcount)>
                    </cfif>
                </cfif>
                <cfcatch></cfcatch>
            </cftry>
            <cfset arguments.stack = push(arguments.stack, Folders[i].getParent().getName())>
            <cfset arguments.list = getFolderStructure(objFolder, Folders[i].getName(), arguments.list, arguments.level + 1, arguments.stack)>
            <cfset Folders = arguments.objFolder.list()>
            <cfset arguments.stack = pop(arguments.stack)>
        </cfloop>
        <cfreturn arguments.list>
    </cffunction>

    <cffunction name="setFlag" access="private" output="No"
        hint="Set an IMAP flag for a specific message or range of messages within the specified folder.">
        <cfargument name="objFolder" required="Yes" type="string">
        <cfargument name="messageNumber" required="Yes" type="string">
        <cfargument name="flag" required="Yes" type="string">
        <cfargument name="value" required="Yes" type="boolean">

        <cfset var Messages = GetMessages(arguments.objFolder, arguments.messageNumber)>
        <cfset var flags = CreateObject("Java", "javax.mail.Flags$Flag")>
        <cfset var i = 0>
        <cfset var objMessage = "">

        <cfloop from="1" to="#arrayLen(Messages)#" step="1" index="i">
            <cfset objMessage = Messages[i]>
            <cfset objMessage.setFlag(flags[flag], value)>
        </cfloop>
        <cfreturn true>
    </cffunction>

    <cffunction name="getParts" access="private" output="false" returnType="struct"
        hint="Get the parts of a message.">
        <cfargument name="objMultipart" type="any" required="yes">

        <cfset var retVal = structNew()>
        <cfset var messageParts = objMultipart.getContent()>
        <cfset var i = 0>
        <cfset var j = 0>
        <cfset var partIndex = 0>
        <cfset var thisPart = "">
        <cfset var disposition = "">
        <cfset var contentType = "">
        <cfset var fo = "">
        <cfset var fso = "">
        <cfset var in = "">
        <cfset var tempFile = "">

        <cfset retVal.parts = ArrayNew(2)>
        <cfset retVal.attachments = "">


        <!--- get all the parts and put it into an array --->
        <!--- [1] = content, [2] = type --->
        <!--- type, 1=text, 2=html, 3=attachment --->
        <cfloop from="0" to="#messageParts.getCount() - 1#" index="i">
            <cfset partIndex = arraylen(retVal.parts) + 1>
            <cfset thisPart = messageParts.getBodyPart(javacast("int", i))>
            <!--- show all attachments as such --->
            <cfif len(thisPart.getFileName())>
                <cfset retVal.attachments = listappend(retVal.attachments, thisPart.getFileName(),chr(1))>
            </cfif>

            <cfif thisPart.isMimeType("multipart/*")>
                <cfset recurseResults = getParts(thisPart)>
                <cfset retVal.parts = push(retVal.parts, recurseResults.parts)>
                <cfset retVal.attachments = listAppend(retVal.attachments, recurseResults.attachments,chr(1))>
            <cfelse>
                <cfset disposition = thisPart.getDisposition()>
                <cfif not isdefined("disposition")> <!--- is javacast("null", "")> --->
                    <cfset contentType = thisPart.getContentType().toString()>
                    <cfif findNoCase("text/plain",contentType) is 1>
                        <cfset retVal.parts[partIndex][1] = thisPart.getContent()>
                        <cfset retVal.parts[partIndex][2] = "1">
                    <cfelseif findNoCase("text/html",contentType) is 1>
                        <!--- This shouldnt happen, at least i dont think --->
                        <!--- note, this should never happen because disposition WILL be defined for HTML parts --->
                        <cfset retVal.parts[partIndex][1] = thisPart.getContent()>
                        <cfset retVal.parts[partIndex][2] = "2">
                    <cfelse>
                        <!--- <cfdump var="other">
                        <cfset retVal.parts[i + 1][1] = "Other Content Type:" & contentType.toString() & "<br>" & part.getContent()>
                        <cfset retVal.parts[i + 1][2] = "3"> --->
                        <cfset fo = createObject("Java", "java.io.File")>
                        <cfset fso = createObject("Java", "java.io.FileOutputStream")>
                        <cfset in = thisPart.getInputStream()>
                        <cfset tempFile = getTempDirectory() & variables._instance.SessionID>
                        <cfset fo.init(tempFile)>
                        <cfset fso.init(fo)>
                        <cfset j = in.read(variables.byteArray)>
                        <cfloop condition="not(j is -1)">
                            <cfset fso.write(variables.byteArray, 0, j)>
                            <cfset j = in.read(variables.byteArray)>
                        </cfloop>
                        <cfset fso.close()>

                        <cffile action="READ" file="#tempFile#" variable="fileContents">
                        <cffile action="DELETE" file="#tempFile#">
                        <cfif findnocase("text/html", fileContents)>
                            <cfset theText = right(fileContents, len(fileContents) - refindnocase("\r\n\r\n", fileContents, findnocase("text/html", fileContents)))>
                            <cfif refind("--+=\S+--", theText)>
                                <cfset theText = left(theText, refind("--+=\S+--", theText) -1)>
                            </cfif>
                            <cfset retVal.parts[partIndex][1] = theText> <!--- replace(theText, "=20#chr(13)#", "~", "ALL")> --->
                            <cfset retVal.parts[partIndex][2] = "2">
                        <cfelse>
                            <cfset retVal.parts[partIndex][1] = fileContents>
                            <cfset retVal.parts[partIndex][2] = "3">
                            <!--- <cfdump var="#thisPart.getContentType()#  name='#thisPart.getFileName()#' #fileContents#"> --->
                        </cfif>
                    </cfif>
                <cfelseif variables.showTextHtmlAttachmentsInline>
                    <!---
                        inline attachments... we already put the filename in
                        the attachments list above, if there was one.  The
                        purpose of this section is to put inline text and HTML
                        attachments INLINE.  I'm personally against this, so
                        I added a "show text and html attachments inline" option.
                    --->
                    <cfif disposition.equalsIgnoreCase(thisPart.INLINE)>
                        <cfset contentType = thisPart.getContentType().toString()>
                        <cfif findNoCase("text/plain",contentType)>
                            <cfset retVal.parts[partIndex][1] = thisPart.getContent()>
                            <cfset retVal.parts[partIndex][2] = "1">
                        <cfelseif findNoCase("text/html",contentType)>
                            <!--- This shouldnt happen, at least i dont think --->
                            <cfset retVal.parts[partIndex][1] = thisPart.getContent()>
                            <cfset retVal.parts[partIndex][2] = "2">
                        <cfelse>
                            <!--- can't do inline attachments right now --->
                        </cfif>
                    <cfelse>
                        <!--- <cfset body = body & "<p>Other: " & disposition & "</p>"> --->
                    </cfif>
                <cfelse>
                    <!---
                        disposition is set, so it's an attachment,
                        but we're not putting *ANY* attachments inline
                        so don't do anything here
                    --->
                </cfif>
            </cfif>
        </cfloop>
        <cfreturn retVal>
    </cffunction>

    <cffunction name="push" access="private" output="yes"
        hint="Add a new item to the end of an array.">
        <cfargument name="stack" type="array" required="yes">
        <cfargument name="value" required="Yes" type="any">

        <cfset var retVal = arguments.stack>
        <cfset var i = 1>

        <cfif isArray(arguments.value)>
            <cfloop from="1" to="#arrayLen(arguments.value)#" step="1" index="i">
                <cfset arrayAppend(retVal, arguments.value[i])>
            </cfloop>
            <cfreturn retVal>
        <cfelse>
            <cfset arrayAppend(retVal, arguments.value)>
            <cfreturn retVal>
        </cfif>
    </cffunction>

    <cffunction name="pop" access="private" output="yes"
        hint="Remove the last item from an array.">
        <cfargument name="stack" type="array" required="yes">

        <cfset var retVal = stack>

        <cfif arraylen(retVal) gt 0>
            <cfset arraydeleteat(retVal, arraylen(retVal))>
        </cfif>
        <cfreturn retVal>
    </cffunction>

</cfcomponent>
