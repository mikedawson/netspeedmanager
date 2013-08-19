#!/bin/bash

#!/bin/bash

VERSION=$1


if [ "$VERSION"	!= "" ]; then
	SWNAME=nsmanager

        cd ~/rpms/SOURCES
        if [ -e $SWNAME-$VERSION.tar.gz ]; then
                rm $SWNAME-$VERSION.tar.gz
       	fi

	if [ -e $SWNAME-$VERSION ]; then
		rm -rf $SWNAME-$VERSION
	fi
	
	cp -r git/nsm/nsmanager-trunk $SWNAME-$VERSION
	
        tar -czf $SWNAME-$VERSION.tar.gz $SWNAME-$VERSION

        cd ~/rpms/SPECS
        rpmbuild -bp $SWNAME.spec
        rpmbuild -ba $SWNAME.spec
else 
	echo "no version defined"
fi


