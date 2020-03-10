# PSLab: Strings and Files

### ISO 639-1 input file (languages.txt):

```
en-US
es-ES
blah blah blah
he-IL
fr-FR
123456789
it-IT
zh-CN
```

### Office configuration deployment example file

```
<Configuration>
  <Add SourcePath="\\Server\Share" 
       OfficeClientEdition="32" Channel="Broad">
    <Product ID="O365ProPlus">
      <Language ID="en-us" />
    </Product>
  </Add>
</Configuration>
```

### Output tree structure

```
root
│   languages.txt
│
└── en-US
│   └── configuration.xml
│   
└── es-ES
│   └── configuration.xml
│   
└── he-IL
    └── configuration.xml
```