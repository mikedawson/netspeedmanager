# Create the user account and password. (This is harmless if the
# user account and password already exist.) Note the reference
# to the 'bwlimits' database which will be created in the next
# few statements.
 
 
 # Create 'bwlimits' database. (Do nothing if the database
 # already exists.)
 
 CREATE DATABASE IF NOT EXISTS bwlimits;
 GRANT ALL PRIVILEGES ON bwlimits.* to 'bwlimit'@'localhost' identified	by '{ $BWLimit{DbPassword} }';
 FLUSH PRIVILEGES;
 
 # Create log_entry table within the 'loggerdemo' database.
 # (Do nothing if the table already exists.)
 
 USE bwlimits;
 
-- MySQL dump 10.13  Distrib 5.1.61, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: bwlimittmp
-- ------------------------------------------------------
-- Server version	5.1.61-0ubuntu0.11.10.1-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `acct`
--
CREATE TABLE IF NOT EXISTS `data_usage` (
  `username` varchar(64) ,
  `kbps_down` int(11) default '0',
  `kbps_up` int(11) default '0',
  `bytes` bigint(20) unsigned NOT NULL default '0',
  `stamp_inserted` bigint(20) unsigned NOT NULL default '0',
   KEY `time_index` (`stamp_inserted`),
   KEY `username_index` (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `data_usage_total` (
  `dlspeed` bigint(20) default NULL,
  `ulspeed` bigint(20) default NULL,
  `stamp_inserted` bigint(20) default NULL,
  KEY `total_time_index` (`stamp_inserted`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `bwlimit_cache_primer` (
  `pid` int(11) default NULL,
  `time_started` int(11) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `speedcheck_control` (
  `timestarted` int(11) default NULL,
  `status` int(11) default NULL,
  `inprogress` int(11) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `connectivity_check` (
  `internet` tinyint default NULL,
  `domain_name` tinyint default NULL,
  `ISP_gateway` tinyint default NULL,
  `total_connectivity` tinyint default NULL,
  `stamp_inserted` bigint(20) unsigned NOT NULL default '0',
  KEY `con_time_index` (`stamp_inserted`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `autoreset_users` (
  `auid` int(11) NOT NULL auto_increment,
  `username` varchar(64) default NULL,
  `password` varchar(64) default NULL,
  `applyday` varchar(32) default NULL,
  `actioned` int(11) default '0',
  PRIMARY KEY  (`auid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


CREATE TABLE IF NOT EXISTS `speed_check` (
  `tx` bigint(20) unsigned NOT NULL default '0',
  `rx` bigint(20) unsigned NOT NULL default '0',
  `stamp_inserted` bigint(20) unsigned NOT NULL default '0',
  KEY `speed_time_index` (`stamp_inserted`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET @saved_cs_client     = @@character_set_client */;

/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `acct` (
  `mac_src` char(17) NOT NULL DEFAULT '',
  `mac_dst` char(17) NOT NULL DEFAULT '',
  `ip_src` char(15) NOT NULL DEFAULT '',
  `ip_dst` char(15) NOT NULL DEFAULT '',
  `src_port` int(2) unsigned NOT NULL DEFAULT '0',
  `dst_port` int(2) unsigned NOT NULL DEFAULT '0',
  `ip_proto` char(6) NOT NULL DEFAULT '',
  `packets` int(10) unsigned NOT NULL DEFAULT '0',
  `bytes` bigint(20) unsigned NOT NULL DEFAULT '0',
  `stamp_inserted` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `stamp_updated` datetime DEFAULT NULL,
  PRIMARY KEY (`mac_src`,`mac_dst`,`ip_src`,`ip_dst`,`src_port`,`dst_port`,`ip_proto`,`stamp_inserted`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `acct`
--

LOCK TABLES `acct` WRITE;
/*!40000 ALTER TABLE `acct` DISABLE KEYS */;
/*!40000 ALTER TABLE `acct` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `acct_squid`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `acct_squid` (
  `mac_src` char(17) NOT NULL DEFAULT '',
  `mac_dst` char(17) NOT NULL DEFAULT '',
  `ip_src` char(15) NOT NULL DEFAULT '',
  `ip_dst` char(15) NOT NULL DEFAULT '',
  `src_port` int(2) unsigned NOT NULL DEFAULT '0',
  `dst_port` int(2) unsigned NOT NULL DEFAULT '0',
  `ip_proto` char(6) NOT NULL DEFAULT '',
  `packets` int(10) unsigned NOT NULL DEFAULT '0',
  `bytes` bigint(20) unsigned NOT NULL DEFAULT '0',
  `stamp_inserted` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `stamp_updated` datetime DEFAULT NULL,
  PRIMARY KEY (`mac_src`,`mac_dst`,`ip_src`,`ip_dst`,`src_port`,`dst_port`,`ip_proto`,`stamp_inserted`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `acct_squid`
--

LOCK TABLES `acct_squid` WRITE;
/*!40000 ALTER TABLE `acct_squid` DISABLE KEYS */;
/*!40000 ALTER TABLE `acct_squid` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `acct_totalin`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `acct_totalin` (
  `mac_src` char(17) NOT NULL DEFAULT '',
  `mac_dst` char(17) NOT NULL DEFAULT '',
  `ip_src` char(15) NOT NULL DEFAULT '',
  `ip_dst` char(15) NOT NULL DEFAULT '',
  `src_port` int(2) unsigned NOT NULL DEFAULT '0',
  `dst_port` int(2) unsigned NOT NULL DEFAULT '0',
  `ip_proto` char(6) NOT NULL DEFAULT '',
  `packets` int(10) unsigned NOT NULL DEFAULT '0',
  `bytes` bigint(20) unsigned NOT NULL DEFAULT '0',
  `stamp_inserted` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `stamp_updated` datetime DEFAULT NULL,
  PRIMARY KEY (`mac_src`,`mac_dst`,`ip_src`,`ip_dst`,`src_port`,`dst_port`,`ip_proto`,`stamp_inserted`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `acct_totalin`
--

LOCK TABLES `acct_totalin` WRITE;
/*!40000 ALTER TABLE `acct_totalin` DISABLE KEYS */;
/*!40000 ALTER TABLE `acct_totalin` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `acct_totalout`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `acct_totalout` (
  `mac_src` char(17) NOT NULL DEFAULT '',
  `mac_dst` char(17) NOT NULL DEFAULT '',
  `ip_src` char(15) NOT NULL DEFAULT '',
  `ip_dst` char(15) NOT NULL DEFAULT '',
  `src_port` int(2) unsigned NOT NULL DEFAULT '0',
  `dst_port` int(2) unsigned NOT NULL DEFAULT '0',
  `ip_proto` char(6) NOT NULL DEFAULT '',
  `packets` int(10) unsigned NOT NULL DEFAULT '0',
  `bytes` bigint(20) unsigned NOT NULL DEFAULT '0',
  `stamp_inserted` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `stamp_updated` datetime DEFAULT NULL,
  PRIMARY KEY (`mac_src`,`mac_dst`,`ip_src`,`ip_dst`,`src_port`,`dst_port`,`ip_proto`,`stamp_inserted`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `acct_totalout`
--

LOCK TABLES `acct_totalout` WRITE;
/*!40000 ALTER TABLE `acct_totalout` DISABLE KEYS */;
/*!40000 ALTER TABLE `acct_totalout` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `connection_status`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `connection_status` (
  `statusid` int(11) NOT NULL DEFAULT '0',
  `gateway_status` tinyint(1) DEFAULT NULL,
  `internet_ip` tinyint(1) DEFAULT NULL,
  `internet_hostname` tinyint(1) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `externalip` varchar(64) DEFAULT NULL,
  `gatewayip` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`statusid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `connection_status`
--

LOCK TABLES `connection_status` WRITE;
/*!40000 ALTER TABLE `connection_status` DISABLE KEYS */;
REPLACE INTO `connection_status` VALUES (1,0,1,1,'2011-03-27 05:19:08','192.168.0.2','192.168.0.1');
/*!40000 ALTER TABLE `connection_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `macipcombos`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `macipcombos` (
  `macaddr` varchar(128) NOT NULL,
  `ipaddr` varchar(128) DEFAULT NULL,
  `leasetimestamp` INT(11) DEFAULT 0,
  PRIMARY KEY (`macaddr`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `macipcombos`
--

LOCK TABLES `macipcombos` WRITE;
/*!40000 ALTER TABLE `macipcombos` DISABLE KEYS */;
/*!40000 ALTER TABLE `macipcombos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `process_log`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `process_log` (
  `id` int(11) NOT NULL DEFAULT '0',
  `last_processed_timestamp` double NOT NULL DEFAULT '0',
  `in_process` tinyint(1) NOT NULL DEFAULT '0',
  `servicename` text NOT NULL,
  `size_last_counted` int(11) DEFAULT NULL,
  `previous_first_timestamp` varchar(255) DEFAULT NULL,
  `setup_type` varchar(255) DEFAULT NULL,
  `depriorate` int(11) DEFAULT NULL,
  `exceedpolicy` varchar(16) DEFAULT NULL,
  `ip_activity_timeout` int(11) DEFAULT NULL,
  `local_ip` varchar(255) DEFAULT NULL,
  `local_netmask` varchar(255) DEFAULT NULL,
  `red_warning_level` float DEFAULT NULL,
  `yellow_warning_level` float DEFAULT NULL,
  `useDynamicRates` tinyint default 0,
  `SpeedFactorDown` float default 1,
  `SpeedFactorUp` float default 1,
  `connection_note` varchar(255) DEFAULT NULL,
  `lastcalcbytetime` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `process_log`
--

LOCK TABLES `process_log` WRITE;
/*!40000 ALTER TABLE `process_log` DISABLE KEYS */;
REPLACE INTO `process_log` VALUES 
(1,1309436152.48,0,'squid',33769,'1309367447.001','ByIP',8,'deprio',1200,'192.168.1.1','255.255.255.0',0.8,0.6,0,1,1,'Primary',unix_timestamp());
/*!40000 ALTER TABLE `process_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `time_ranges`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `time_ranges` (
  `timerange_time_name` varchar(128) NOT NULL DEFAULT '',
  `timerange_timerange` varchar(255) DEFAULT NULL,
  `timerange_rate` float DEFAULT NULL,
  PRIMARY KEY (`timerange_time_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `time_ranges`
--

LOCK TABLES `time_ranges` WRITE;
/*!40000 ALTER TABLE `time_ranges` DISABLE KEYS */;
REPLACE INTO `time_ranges` VALUES ('official_hrs','ASMTWH 08:00-17:26',40),('always','MTWHFAS',1);
/*!40000 ALTER TABLE `time_ranges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usage_logs`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `usage_logs` (
  `userlogid` varchar(255) NOT NULL DEFAULT '',
  `user` varchar(255) NOT NULL DEFAULT '',
  `dayindex` int(11) NOT NULL DEFAULT '0',
  `usage` int(11) NOT NULL DEFAULT '0',
  `usage_bytes` int(11) DEFAULT '0',
  `saved_bytes` int(11) DEFAULT '0',
  `saved_time` int(11) DEFAULT '0',
  PRIMARY KEY (`userlogid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usage_logs`
--

LOCK TABLES `usage_logs` WRITE;
/*!40000 ALTER TABLE `usage_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `usage_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_details`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `user_details` (
  `username` varchar(255) NOT NULL DEFAULT '',
  `daily_limit` bigint(20) NOT NULL DEFAULT '0',
  `weekly_limit` bigint(32) NOT NULL DEFAULT '0',
  `monthly_limit` bigint(32) NOT NULL DEFAULT '0',
  `ratedown` int(11) DEFAULT NULL,
  `ceildown` int(11) DEFAULT NULL,
  `rateup` int(11) DEFAULT NULL,
  `ceilup` int(11) DEFAULT NULL,
  `within_quota` tinyint(1) NOT NULL DEFAULT '0',
  `active_ip_addr` varchar(255) DEFAULT NULL,
  `last_ip_activity` bigint(20) DEFAULT NULL,
  `is_guest_account` tinyint(1) DEFAULT NULL,
  `can_create_guest_acct` tinyint(1) DEFAULT NULL,
  `expires_utime` int(11) DEFAULT NULL,
  `created_by` varchar(128) DEFAULT NULL,
  `guest_pw` varchar(128) DEFAULT NULL,
  `current_kbps` int(11) DEFAULT NULL,
  `mac_addr1` varchar(255) DEFAULT NULL,
  `mac_addr2` varchar(255) DEFAULT NULL,
  `ip_addr` varchar(255) DEFAULT NULL,
  `login_method` varchar(32) DEFAULT NULL,
  `session_start_time` int(11) DEFAULT NULL,
  `blockdirecthttps` int(11) DEFAULT '0',
  `htbparentclass` int(11) DEFAULT '0',
  PRIMARY KEY (`username`),
  UNIQUE KEY `username` (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_details`
--

LOCK TABLES `user_details` WRITE;
/*!40000 ALTER TABLE `user_details` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_details` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usersavedmacs`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `usersavedmacs` (
  `macaddr` varchar(128) NOT NULL,
  `username` varchar(128) DEFAULT NULL,
  `comment` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`macaddr`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usersavedmacs`
--

LOCK TABLES `usersavedmacs` WRITE;
/*!40000 ALTER TABLE `usersavedmacs` DISABLE KEYS */;
/*!40000 ALTER TABLE `usersavedmacs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `xfer_requests`
--


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE IF NOT EXISTS `xfer_requests` (
  `requestid` int(11) NOT NULL AUTO_INCREMENT,
  `url` text,
  `user` varchar(255) DEFAULT NULL,
  `pid` int(11) DEFAULT NULL,
  `countedbytes` bigint(20) DEFAULT NULL,
  `total_size` bigint(20) DEFAULT NULL,
  `output_file` text,
  `dest_file` text,
  `type` varchar(32) DEFAULT NULL,
  `status` varchar(32) DEFAULT NULL,
  `start_time` int(11) DEFAULT NULL,
  `stop_utime` int(11) DEFAULT NULL,
  `comment` varchar(128) DEFAULT NULL,
  `ftp_hostname` varchar(255) DEFAULT NULL,
  `ftp_username` varchar(255) DEFAULT NULL,
  `ftp_pass` varchar(255) DEFAULT NULL,
  `upload_count` int(11) DEFAULT '0',
  `last_counted` int(11) DEFAULT NULL,
  PRIMARY KEY (`requestid`)
) ENGINE=MyISAM AUTO_INCREMENT=73 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `xfer_requests`
--

LOCK TABLES `xfer_requests` WRITE;
/*!40000 ALTER TABLE `xfer_requests` DISABLE KEYS */;
/*!40000 ALTER TABLE `xfer_requests` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2012-05-09 15:56:32
