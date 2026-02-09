# Specification of the du (disk usage) utility.

The goal is to make a command line disk usage utility. It recursively enumerates
a folder summing the size of all files in the folder. It remembers the inclusive
and exclusive (that is only files in the that folder and not its sub folders),
and sorts the directories by inclusive size, and prints all entries that are
larger than a minimum size. This lets you quickly determine which areas of your
file system hierarchy are consuming space.

Because this enumeration may take a while, the utility will print a dot for
every 100 files it processes. After printing 80 dots a newline is output so that
the output line does not get too long. After the last dot, it outputs a newline
and a the time it took to run.

It should also respond to the argument -? printing a help message and indicated
in the next section. There is also a section which shows a sample output.

The program should be written in python. It should follow best practices for the
language for command line utilities.

## Help Text (This is printed when du -? is executed)

    Usage: du [folder]

    Summarize the disk usage for a folder (including sub folders)

    Parameters:
        [folder]        The directory to summarize, defaults to the current directory
    Qualifiers:
        [-Percent:Num]   Trim directories to less than this percentage defaults to 1.

## Sample Output

        > du.py
        Getting disk usage for: .
        ..................................................
        Elaped time = 00:00:00.21

        Inclusive     Exclusive       Directory
        Size           Size
        ----------------------------------------------------------------------------
        4123.27M      282.59M      .
        2955.53M        2.17M      .\callerSchool
        1655.98M        0.00M      .\callerSchool\purchasedMusic
        1364.92M        0.00M      .\callerSchool\purchasedMusic\singingCalls
        1289.26M       68.05M      .\callerSchool\sqview
        1201.64M      649.30M      .\callerSchool\sqview\mp3
        358.71M       358.71M      .\callerSchool\sqview\mp3\patter
        206.62M       206.62M      .\callerSchool\purchasedMusic\patter
        169.27M        73.72M      .\bin
        168.04M         0.00M      .\desk1
        168.04M        58.81M      .\desk1\Documents
        156.38M        10.00M      .\old
        156.04M       156.04M      .\callerSchool\sqview\mp3\vocal
        143.77M         1.51M      .\old\Teals
        140.41M        66.10M      .\old\Teals\old
         83.16M         0.07M      .\My Kindle Content
         41.63M         0.00M      .\desk1\Documents\old
         41.63M        13.79M      .\desk1\Documents\old\office
