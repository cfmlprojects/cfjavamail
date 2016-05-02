<cfcomponent displayname="TestInstall"  extends="mxunit.framework.TestCase">

  <cffunction name="setUp" returntype="void" access="public">
		<cfset javamail = createObject("component","cfjavamail.tag.cfjavamail.cfc.javamail") />
<!---
		<cffile action="read" file="#expandpath('/cfjavamail')#/tests/tag/mail.user.pass.txt" variable="userpass" />
		<cfset variables.username = listFirst(userpass,"=") />
		<cfset variables.password = listLast(userpass,"=") />
 --->
		<cfset variables.username = "to@127.0.0.1" />
		<cfset variables.password = "randompass" />
		<cfset mstoreStore = "mstor:/tmp/fart" />
		<cfset greenmail(action="start") />
		<cfset greenmail(action="setUser", email=username,password=password) />
		<cftry>
			<cfset createObject("java","net.fortuna.mstor.MStorStore") />
			<cfcatch>
				<cfscript>
					var testInstall = createObject("tests.cfjavamail.extension.TestInstall");
					testInstall.setup();
					testInstall.testAddJars(uninstall=false);
				</cfscript>
			</cfcatch>
		</cftry>
		<cftry>
			<cfset directoryDelete("/tmp/fart.sbd",true) />
			<cfcatch></cfcatch>
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

	<cffunction name="testPOP3SSL">
		<cfscript>
		var protocol="pop3";
		var mailserver="127.0.0.1";
		var port="3995";
		var timeout="3";
		var username=variables.username;
		var password=variables.password;
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		var connected = javamail._init(protocol,username,password,mailserver,port,timeout);
		assertTrue(connected);
		assertEquals(javamail.getMessageCount("INBOX"),1);
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		assertEquals(javamail.getMessageCount("INBOX"),2);
		messageList = javamail.listMessages("INBOX","",0,10);
		request.debug(messageList);
		</cfscript>
	</cffunction>

	<cffunction name="testIMAPS">
		<cfscript>
		var protocol="imaps";
		var mailserver="127.0.0.1";
		var port="3993";
		var timeout="3";
		var username=variables.username;
		var password=variables.password;
		SSLCertificateInstall("127.0.0.1",3465);
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		var connected = javamail._init(protocol,username,password,mailserver,port);
		assertTrue(connected);
		debug(javamail.getFolderInfo("INBOX"));
		debug(javamail.getMessageCount("INBOX"));
		assertEquals(javamail.getMessageCount("INBOX"),1);
		messageList = javamail.listMessages("INBOX","",1,10);
		debug(messageList);
		</cfscript>
	</cffunction>

	<cffunction name="testIMAP">
		<cfscript>
		var protocol="imap";
		var port="3143";
		var mailserver="127.0.0.1";
		var timeout="3";
		var username=variables.username;
		var password=variables.password;
		var connected = javamail._init(protocol=protocol,username=username,password=password,mailserver=mailserver,port=port,timeout=5,useTLS=false,useSSL=false,allowFallback=false);
		assertTrue(connected);
		debug(javamail.getFolderInfo("INBOX"));
		debug(javamail.getMessageCount("INBOX"));
		messageList = javamail.listMessages("INBOX","",1,10);
		debug(messageList);
		</cfscript>
	</cffunction>

	<cffunction name="testMSTOR">
		<cfscript>
		var protocol="mstor";
		var mailserver="mstor:/tmp/fart";
		var timeout="3";
		var username=variables.username;
		var password=variables.password;
		var connected = javamail._init(protocol=protocol,username=username,password=password,mailserver=mailserver,port=993,timeout=5,useTLS=true,useSSL=true,allowFallback=false);
		assertTrue(connected);
		var fi = javamail.getFolderInfo("INBOX");
		debug(fi);
		if(!fi.exists){
			debug(javamail.folderCreate("INBOX"));
		}
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		debug(javamail.getMessageCount("INBOX"));
		messageList = javamail.listMessages("INBOX","",1,10);
		debug(messageList);
		</cfscript>
	</cffunction>

	<cffunction name="testCopyIMAPtoMSTOR">
		<cfsetting requesttimeout="9999" />
		<cfscript>
		var protocol="imaps";
		var mailserver="127.0.0.1";
		var timeout="3";
		var username=variables.username;
		var password=variables.password;
		var ibox = createObject("component","cfjavamail.tag.cfjavamail.cfc.javamail");
		var mbox = createObject("component","cfjavamail.tag.cfjavamail.cfc.javamail");
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		var connected = ibox._init(protocol=protocol,username=username,password=password,mailserver=mailserver,port=3993,timeout=5,useTLS=true,useSSL=true,allowFallback=false);
		assertTrue(connected);
		assertEquals(ibox.getMessageCount("INBOX"),3);
		connected = mbox._init(protocol="mstor",username=username,password=password,mailserver=mstoreStore);
		assertTrue(connected);
		var fi = mbox.getFolderInfo("INBOX");
		if(!fi.exists){
			mbox.folderCreate("INBOX");
		}
		assertEquals(mbox.getMessageCount("INBOX"),0);
		messageList = ibox.listMessages("INBOX","",1,10);
		infoArray = mbox.copyFolder(ibox.getFolder("INBOX"),mbox.getFolder("INBOX"),5);
		//infoArray = mbox.copyFolder(ibox.getFolder("INBOX"),mbox.getFolder("INBOX"),150);
		messageList = mbox.listMessages("INBOX","",1,10);
		assertEquals(ibox.getMessageCount("INBOX"),3);
		assertEquals(mbox.getMessageCount("INBOX"),3);
		request.debug(infoArray);
		</cfscript>
	</cffunction>

	<cffunction name="testMoveIMAPtoMSTOR">
		<cfsetting requesttimeout="9999" />
		<cfscript>
		var protocol="imaps";
		var mailserver="127.0.0.1";
		var timeout="3";
		var username=variables.username;
		var password=variables.password;
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		greenmail(action="sendTextEmailTest",to="to@127.0.0.1",from="from@127.0.0.1",subject="subject",body="body");
		var ibox = createObject("component","cfjavamail.tag.cfjavamail.cfc.javamail");
		var mbox = createObject("component","cfjavamail.tag.cfjavamail.cfc.javamail");

		var connected = ibox._init(protocol=protocol,username=username,password=password,mailserver=mailserver,port=3993,timeout=5,useTLS=true,useSSL=true,allowFallback=false);
		assertTrue(connected);
		assertEquals(ibox.getMessageCount("INBOX"),3);

		connected = mbox._init(protocol="mstor",username=username,password=password,mailserver=mstoreStore);
		assertTrue(connected);
		var fi = mbox.getFolderInfo("INBOX");
		if(!fi.exists){
			mbox.folderCreate("INBOX");
		}
		assertEquals(mbox.getMessageCount("INBOX"),0);
		infoArray = mbox.moveToFolder(ibox.getFolder("INBOX"),mbox.getFolder("INBOX"),5);
		request.debug(infoArray);
		assertEquals(0, ibox.getMessageCount("INBOX"));
		assertEquals(3, mbox.getMessageCount("INBOX"));
		messageList = mbox.listMessages("INBOX","",1,10);
		</cfscript>
	</cffunction>

	<cffunction name="testSendSSL">
		<cfscript>
		var protocol="smtp";
		//var mailserver="smtp.gmail.com";
		var mailserver="127.0.0.1";
		var timeout="3";
		var port="3465";
		var username=variables.username;
		var password=variables.password;
		var connected = javamail._init(protocol=protocol,username=username,password=password,mailserver=mailserver,port=port,timeout=2,useTLS=false,useSSL=true,allowFallback=false);

		var mailTo="valliantster@gmail.com";
		var cc="valliantster@gmail.com";
		var bcc="valliantster@gmail.com";
		var subject="testing more esse!";
		var body="this is a test";
		var attachments="";
		var sent = javamail.send(to=mailTo,cc=cc,bcc=bcc,subject=subject,body=body,attachments=attachments);
		assertTrue(sent);
		sent = javamail.send(to=mailTo,cc=cc,subject=subject,body=body);
		assertTrue(sent);
		sent = javamail.send(to=mailTo,subject=subject,body=body);
		assertTrue(sent);
		sent = javamail.send(to=mailTo,body=body);
		assertTrue(sent);
		messages = greenmail(action="getReceivedMessages");
		assertEquals(subject, messages[1].getSubject());
		</cfscript>
	</cffunction>

	<cffunction name="testSendTLS">
		<cfscript>
		var protocol="smtp";
		//var mailserver="smtp.gmail.com";
		var mailserver="127.0.0.1";
		var timeout="3";
		var port="3025";
		var username=variables.username;
		var password=variables.password;
		var connected = javamail._init(protocol=protocol,username=username,password=password,mailserver=mailserver,port=port,timeout=2,useTLS=true,useSSL=false,allowFallback=false);
		//var connected = javamail._init(protocol,username,password,mailserver,587,2,true);

		var mailTo="valliantster@gmail.com";
		var cc="valliantster@gmail.com";
		var bcc="valliantster@gmail.com";
		var subject="testing more esse!";
		var body="this is a test";
		var attachments="";
		var sent = javamail.send(mailTo,cc,bcc,subject,body,attachments);
		assertTrue(sent);
		</cfscript>
	</cffunction>

</cfcomponent>