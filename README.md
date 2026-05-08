# ☕ Café Volcán — Laboratorio Práctico 1 FDICI12

## Integrante

- Benjamin Tabilo

## Emprendimiento

**Café Volcán** es una tienda de café de especialidad ubicada en Frutillar Bajo, Región de Los Lagos.
El sitio web presenta la carta de productos, la historia del negocio y la información de contacto.

## Acceso al sitio web

http://44.200.26.35

## Infraestructura AWS desplegada

| Recurso          | ID                       |
| ---------------- | ------------------------ |
| VPC              | vpc-0b81f80fe1f9d2926    |
| Subred pública   | subnet-0a7993d34394a90ca |
| Subred privada   | subnet-0c1f95f5cafe5d9ed |
| Internet Gateway | igw-0ad27dbaf51dadbff    |
| Security Group   | sg-0aa4306bbc84512c7     |
| Instancia EC2    | i-02db4bf780bee7c8d      |
| Volumen EBS      | vol-07b90ea4597b81c94    |

## Instrucciones para ejecutar el script

### Requisitos

- AWS CLI instalado y configurado con credenciales válidas
- Bash (Linux/Mac) o Git Bash (Windows)

### Ejecución

```bash
cd infraestructura
bash deploy.sh
```

## Estructura del repositorio

## Estructura del repositorio

```
lab1-cafe-volcan/
├── infraestructura/
│   └── deploy.sh
├── sitio-web/
│   └── index.html
├── documentacion/
│   ├── arquitectura.pdf
│   └── capturas/
└── README.md
```
