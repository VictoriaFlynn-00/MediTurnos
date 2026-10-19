CREATE DATABASE  IF NOT EXISTS `mediturnosapp` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `mediturnosapp`;
-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: mediturnosapp
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `especialidades`
--

DROP TABLE IF EXISTS `especialidades`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `especialidades` (
  `id_especialidad` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  PRIMARY KEY (`id_especialidad`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `especialidades`
--

LOCK TABLES `especialidades` WRITE;
/*!40000 ALTER TABLE `especialidades` DISABLE KEYS */;
/*!40000 ALTER TABLE `especialidades` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `especialistas`
--

DROP TABLE IF EXISTS `especialistas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `especialistas` (
  `id_especialista` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `apellido` varchar(100) NOT NULL,
  `fechaNacimiento` date NOT NULL,
  `domicilio` varchar(200) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `especialidad` int DEFAULT NULL,
  `DNI` int DEFAULT NULL,
  PRIMARY KEY (`id_especialista`),
  UNIQUE KEY `DNI` (`DNI`),
  KEY `especialidad` (`especialidad`),
  CONSTRAINT `especialistas_ibfk_1` FOREIGN KEY (`especialidad`) REFERENCES `especialidades` (`id_especialidad`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `especialistas`
--

LOCK TABLES `especialistas` WRITE;
/*!40000 ALTER TABLE `especialistas` DISABLE KEYS */;
/*!40000 ALTER TABLE `especialistas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `historialclinico`
--

DROP TABLE IF EXISTS `historialclinico`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `historialclinico` (
  `id_historial` int NOT NULL AUTO_INCREMENT,
  `pacienteDNI` int NOT NULL,
  `especialistaID` int NOT NULL,
  `fecha` date NOT NULL,
  `diagnostico` varchar(255) NOT NULL,
  `tratamiento` varchar(255) DEFAULT NULL,
  `observaciones` text,
  PRIMARY KEY (`id_historial`),
  KEY `pacienteDNI` (`pacienteDNI`),
  KEY `especialistaID` (`especialistaID`),
  CONSTRAINT `historialclinico_ibfk_1` FOREIGN KEY (`pacienteDNI`) REFERENCES `pacientes` (`id_paciente`),
  CONSTRAINT `historialclinico_ibfk_2` FOREIGN KEY (`especialistaID`) REFERENCES `especialistas` (`id_especialista`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `historialclinico`
--

LOCK TABLES `historialclinico` WRITE;
/*!40000 ALTER TABLE `historialclinico` DISABLE KEYS */;
/*!40000 ALTER TABLE `historialclinico` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notificaciones`
--

DROP TABLE IF EXISTS `notificaciones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notificaciones` (
  `id_notificacion` int NOT NULL AUTO_INCREMENT,
  `mensaje` varchar(255) NOT NULL,
  `tipo` enum('recordatorio','aviso') NOT NULL,
  `usuario` int NOT NULL,
  `turno` int NOT NULL,
  PRIMARY KEY (`id_notificacion`),
  KEY `usuario` (`usuario`),
  KEY `turno` (`turno`),
  CONSTRAINT `notificaciones_ibfk_1` FOREIGN KEY (`usuario`) REFERENCES `usuarios` (`id_usuario`),
  CONSTRAINT `notificaciones_ibfk_2` FOREIGN KEY (`turno`) REFERENCES `turnos` (`id_turno`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notificaciones`
--

LOCK TABLES `notificaciones` WRITE;
/*!40000 ALTER TABLE `notificaciones` DISABLE KEYS */;
/*!40000 ALTER TABLE `notificaciones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pacientes`
--

DROP TABLE IF EXISTS `pacientes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pacientes` (
  `id_paciente` int NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `apellido` varchar(100) NOT NULL,
  `fechaNacimiento` date NOT NULL,
  `domicilio` varchar(200) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `obraSocial` varchar(100) DEFAULT NULL,
  `usuarioID` int DEFAULT NULL,
  PRIMARY KEY (`id_paciente`),
  UNIQUE KEY `usuarioID` (`usuarioID`),
  CONSTRAINT `fk_paciente_usuario` FOREIGN KEY (`usuarioID`) REFERENCES `usuarios` (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pacientes`
--

LOCK TABLES `pacientes` WRITE;
/*!40000 ALTER TABLE `pacientes` DISABLE KEYS */;
/*!40000 ALTER TABLE `pacientes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `secretarios`
--

DROP TABLE IF EXISTS `secretarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `secretarios` (
  `id_secretario` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `apellido` varchar(100) NOT NULL,
  `fechaNacimiento` date NOT NULL,
  `domicilio` varchar(200) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `DNI` int DEFAULT NULL,
  `usuario` int NOT NULL,
  PRIMARY KEY (`id_secretario`),
  UNIQUE KEY `DNI` (`DNI`),
  KEY `fk_secretario_usuario_idx` (`usuario`),
  CONSTRAINT `fk_secretario_usuario` FOREIGN KEY (`usuario`) REFERENCES `usuarios` (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `secretarios`
--

LOCK TABLES `secretarios` WRITE;
/*!40000 ALTER TABLE `secretarios` DISABLE KEYS */;
/*!40000 ALTER TABLE `secretarios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `turnos`
--

DROP TABLE IF EXISTS `turnos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `turnos` (
  `id_turno` int NOT NULL AUTO_INCREMENT,
  `fecha` date NOT NULL,
  `hora` time NOT NULL,
  `paciente` int NOT NULL,
  `especialista` int NOT NULL,
  `estado` enum('activo','cancelado','reprogramado') DEFAULT 'activo',
  PRIMARY KEY (`id_turno`),
  KEY `paciente` (`paciente`),
  KEY `especialista` (`especialista`),
  CONSTRAINT `turnos_ibfk_1` FOREIGN KEY (`paciente`) REFERENCES `pacientes` (`id_paciente`),
  CONSTRAINT `turnos_ibfk_2` FOREIGN KEY (`especialista`) REFERENCES `especialistas` (`id_especialista`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `turnos`
--

LOCK TABLES `turnos` WRITE;
/*!40000 ALTER TABLE `turnos` DISABLE KEYS */;
/*!40000 ALTER TABLE `turnos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios` (
  `id_usuario` int NOT NULL AUTO_INCREMENT,
  `usuario` varchar(100) NOT NULL,
  `contrasena_hash` varchar(100) NOT NULL,
  `rol` enum('paciente','secretario','especialista','admin') NOT NULL,
  PRIMARY KEY (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usuarios`
--

LOCK TABLES `usuarios` WRITE;
/*!40000 ALTER TABLE `usuarios` DISABLE KEYS */;
/*!40000 ALTER TABLE `usuarios` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-05 16:20:40
