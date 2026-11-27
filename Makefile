PORTNAME=	lsu
DISTVERSION=	0.1
CATEGORIES=	games

MAINTAINER=	thuggerthugger1@duck.com
COMMENT=	Steam launcher for a custom Linuxulator root
WWW=		https://github.com/Gur0v/linuxulator-steam-utils-standalone

LICENSE=	MIT
LICENSE_FILE=	${.CURDIR}/LICENSE
ONLY_FOR_ARCHS=	amd64

RUN_DEPENDS=	gtar:archivers/gtar \
		zenity:x11/zenity
USES=		ruby:run

# This port builds the checked-out source, not a downloaded distribution.
NO_WRKSUBDIR=	yes
DISTFILES=
EXTRACT_ONLY=
NO_CHECKSUM=	yes
LINUXBASE?=	/compat/linux

PLIST_FILES=	# supplied by pkg-plist

do-build:
	${MAKE_CMD} -C ${.CURDIR} -f Makefile.build BUILD_DIR=${WRKDIR}/build LINUXBASE=${LINUXBASE} build

do-install:
	${MAKE_CMD} -C ${.CURDIR} -f Makefile.build BUILD_DIR=${WRKDIR}/build LINUXBASE=${LINUXBASE} PREFIX=${PREFIX} DESTDIR=${STAGEDIR} install
	${MKDIR} ${STAGEDIR}${PREFIX}/bin
	${LN} -s ../steam-utils/bin/steam ${STAGEDIR}${PREFIX}/bin/steam
	${LN} -s ../steam-utils/bin/lsu-wine-env ${STAGEDIR}${PREFIX}/bin/lsu-wine-env

.include <bsd.port.pre.mk>
.if ${OSVERSION} < 1501000
IGNORE=		requires FreeBSD 15.1 or newer
.endif
.include <bsd.port.post.mk>
